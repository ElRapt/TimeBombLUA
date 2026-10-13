local ADDON, ns = ...
local Wire = {}
Wire.__index = Wire
ns.Wire = Wire
local control={INVITE=true,INVITE_SEEN=true,DECLINE=true,JOIN=true,JOIN_ACK=true,JOIN_REJECT=true,
    INTENT=true,RESULT=true,HEARTBEAT=true,PONG=true,RESUME=true,RESYNC=true,RECOVER=true,RECONCILE=true,CLOSED=true,SUSPEND=true,LEAVE=true,TERMINAL_ACK=true}
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local lookup = {}
for i = 1, #alphabet do lookup[alphabet:sub(i,i)] = i - 1 end
local function encode64(s)
    local out = {}
    for i = 1, #s, 3 do
        local a,b,c = s:byte(i,i+2); b,c = b or 0,c or 0
        local n = a * 65536 + b * 256 + c
        out[#out+1] = alphabet:sub(math.floor(n/262144)%64+1,math.floor(n/262144)%64+1)
            .. alphabet:sub(math.floor(n/4096)%64+1,math.floor(n/4096)%64+1)
            .. (i+1<=#s and alphabet:sub(math.floor(n/64)%64+1,math.floor(n/64)%64+1) or "=")
            .. (i+2<=#s and alphabet:sub(n%64+1,n%64+1) or "=")
    end
    return table.concat(out)
end
local function decode64(s)
    if #s % 4 ~= 0 or #s > 43692 then return nil end
    local out = {}
    for i = 1,#s,4 do
        local a,b,c,d = s:sub(i,i),s:sub(i+1,i+1),s:sub(i+2,i+2),s:sub(i+3,i+3)
        if not lookup[a] or not lookup[b] or (c~="=" and not lookup[c]) or (d~="=" and not lookup[d]) then return nil end
        if (c=="=" and d~="=") or ((c=="=" or d=="=") and i+3~=#s) then return nil end
        local n = lookup[a]*262144+lookup[b]*4096+(lookup[c] or 0)*64+(lookup[d] or 0)
        out[#out+1] = string.char(math.floor(n/65536)%256)
        if c~="=" then out[#out+1] = string.char(math.floor(n/256)%256) end
        if d~="=" then out[#out+1] = string.char(n%256) end
    end
    return table.concat(out)
end
local function peerOK(s) return type(s)=="string" and #s>0 and #s<=160 and not s:find("[%z\1-\31|]") end
function Wire.New(opts)
    return setmetatable({now=opts.now,rawSend=opts.rawSend,receive=opts.receive,
        notice=opts.notice or function() end,queue={},queuedBytes=0,partials={},partialCount=0,
        partialBytes=0,completed={},completedOrder={},serial=0,tokens=800,last=opts.now()},Wire)
end
function Wire:Send(target,envelope)
    if not peerOK(target) then return false,"TARGET" end
    local encoded,err = ns.Codec.Encode(envelope)
    if not encoded then self.notice("MALFORMED",err); return false,err end
    local payload=encode64(encoded)
    -- Supersede only wholly unsent presence/projection messages. Once a fragment
    -- has left, preserve the rest so receivers can finish that message.
    if envelope.kind=="SNAPSHOT" or envelope.kind=="HEARTBEAT" then
        for i=#self.queue,1,-1 do
            local q=self.queue[i]
            if q.next==1 and q.target==target and q.kind==envelope.kind and q.sessionId==envelope.sessionId then
                self.queuedBytes=self.queuedBytes-q.bytes; table.remove(self.queue,i)
            end
        end
    end
    if #self.queue>=64 or self.queuedBytes+#payload>262144 then self.notice("NETWORK_BUSY"); return false,"QUEUE" end
    self.serial=(self.serial+1)%10000000
    local id=string.format("%x-%x",math.floor(self.now())%2147483647,self.serial)
    local n=math.ceil(#payload/200)
    if n>220 then return false,"SIZE" end
    local fragments={}
    for i=1,n do fragments[i]="1:"..id..":"..i..":"..n..":"..payload:sub((i-1)*200+1,i*200) end
    self.queue[#self.queue+1]={target=target,kind=envelope.kind,sessionId=envelope.sessionId,
        fragments=fragments,next=1,bytes=#payload,created=self.now(),order=self.serial,failures=0,priority=control[envelope.kind] and 2 or (envelope.kind=="JOINED" and 1 or 0)}
    self.queuedBytes=self.queuedBytes+#payload
    return true
end
function Wire:DropPartial(key)
    local p=self.partials[key]
    if p then self.partialBytes=self.partialBytes-p.bytes; self.partialCount=self.partialCount-1; self.partials[key]=nil end
end
function Wire:Receive(sender,fragment)
    if not peerOK(sender) or type(fragment)~="string" or #fragment>240 then return false end
    local id,index,total,body=fragment:match("^1:([%x%-]+):(%d+):(%d+):([A-Za-z0-9+/=]+)$")
    index,total=tonumber(index),tonumber(total)
    if not id or #id>24 or not index or not total or total<1 or total>220 or index<1 or index>total or #body>200 then return false end
    local key=sender.."/"..id
    if self.completed[key] then return true end
    local p=self.partials[key]
    if not p then
        local count=0
        for _,v in pairs(self.partials) do if v.sender==sender then count=count+1 end end
        if self.partialCount>=32 or count>=4 then return false end
        p={sender=sender,total=total,parts={},count=0,bytes=0,created=self.now()}
        self.partials[key]=p; self.partialCount=self.partialCount+1
    end
    if p.total~=total then self:DropPartial(key); return false end
    if p.parts[index] then
        if p.parts[index]~=body then self:DropPartial(key); return false end
        return true
    end
    if self.partialBytes+#body>262144 or p.bytes+#body>43692 then self:DropPartial(key); return false end
    p.parts[index]=body; p.count=p.count+1; p.bytes=p.bytes+#body; self.partialBytes=self.partialBytes+#body
    if p.count==p.total then
        local raw=decode64(table.concat(p.parts)); self:DropPartial(key)
        if not raw then return false end
        local message=ns.Codec.Decode(raw)
        if type(message)~="table" then return false end
        self.completed[key]=self.now(); self.completedOrder[#self.completedOrder+1]=key
        while #self.completedOrder>128 do self.completed[table.remove(self.completedOrder,1)]=nil end
        self.receive(sender,message)
    end
    return true
end
function Wire:Tick()
    local now=self.now()
    self.tokens=math.min(1600,self.tokens+math.max(0,now-self.last)*800); self.last=now
    for key,p in pairs(self.partials) do if now-p.created>90 then self:DropPartial(key) end end
    for key,time in pairs(self.completed) do if now-time>120 then self.completed[key]=nil end end
    -- Round-robin complete fragments keeps a large snapshot from starving another
    -- peer. Application acknowledgement, not a local send result, proves receipt.
    local attempts=0
    while #self.queue>0 and self.tokens>=240 and attempts<64 do
        attempts=attempts+1
        local best
        for i,q in ipairs(self.queue) do
            local blocked=false
            if q.priority<2 then
                for _,other in ipairs(self.queue) do
                    if other.target==q.target and other.priority<2 and other.order<q.order then blocked=true; break end
                end
            end
            if not blocked and (not best or q.priority>self.queue[best].priority) then best=i end
        end
        if not best then break end
        local q=table.remove(self.queue,best)
        if now-q.created>180 then self.queuedBytes=self.queuedBytes-q.bytes; self.notice("NO_RESPONSE",q.target)
        else
            local fragment=q.fragments[q.next]
            local ok,err=self.rawSend(q.target,fragment)
            self.tokens=self.tokens-#fragment
            if ok==true then q.next=q.next+1; q.failures=0
            else q.failures=q.failures+1 end
            if q.next>#q.fragments then self.queuedBytes=self.queuedBytes-q.bytes
            elseif q.failures>=3 then self.queuedBytes=self.queuedBytes-q.bytes; self.notice("NETWORK_BUSY",err or q.target)
            else self.queue[#self.queue+1]=q end
            if ok~=true then break end
        end
    end
end
function Wire:Clear()
    self.queue={}; self.queuedBytes=0; self.partials={}; self.partialBytes=0; self.partialCount=0
    self.completed={}; self.completedOrder={}
end
-- Called when the sole live session closes. Keep only bounded terminal delivery
-- work, so departure acknowledgement survives while secrets leave the queue.
function Wire:PurgeSession(sessionId)
    for i=#self.queue,1,-1 do
        local q=self.queue[i]
        if (not sessionId or q.sessionId==sessionId) and q.kind~="CLOSED" and q.kind~="LEAVE" and q.kind~="TERMINAL_ACK" then
            self.queuedBytes=self.queuedBytes-q.bytes; table.remove(self.queue,i)
        end
    end
    for key in pairs(self.partials) do self:DropPartial(key) end
end
