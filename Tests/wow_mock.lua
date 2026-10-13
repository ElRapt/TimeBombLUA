-- Native call contract smoke double. This is NOT a WoW renderer or live API test.
local mock={objects={},timers={},sounds=0,clock=1000}
local M={}; M.__index=M
local function make(kind,name,parent)
    local o=setmetatable({kind=kind,name=name,parent=parent,scripts={},hooks={},shown=true,enabled=true,w=0,h=0,scale=1,alpha=1,points={}},M)
    mock.objects[#mock.objects+1]=o
    if name then _G[name]=o end
    return o
end
function M:SetScript(k,fn) assert(type(k)=='string'); self.scripts[k]=fn end
function M:HookScript(k,fn) self.hooks[k]=fn end
function M:Fire(k,...) if self.scripts[k] then self.scripts[k](self,...) end; if self.hooks[k] then self.hooks[k](self,...) end end
function M:Show() local old=self.shown; self.shown=true; if not old then self:Fire('OnShow') end end
function M:Hide() local old=self.shown; self.shown=false; if old then self:Fire('OnHide') end end
function M:IsShown() return self.shown end
function M:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function M:SetShown(v) if v then self:Show() else self:Hide() end end
function M:SetEnabled(v) self.enabled=not not v end
function M:Enable() self.enabled=true; self:Fire('OnEnable') end
function M:Disable() self.enabled=false; self:Fire('OnDisable') end
function M:IsEnabled() return self.enabled end
function M:SetSize(w,h) assert(type(w)=='number' and type(h)=='number'); self.w=w; self.h=h end
function M:SetWidth(v) self.w=v end
function M:SetHeight(v) self.h=v end
function M:GetHeight() return self.h end
function M:GetWidth() return self.w end
function M:SetScale(s) self.scale=s end
function M:GetScale() return self.scale end
function M:GetCenter() return 700,450 end
function M:SetPoint(...) self.points[#self.points+1]={...} end
function M:SetAllPoints(other) self.allPoints=other or self.parent end
function M:ClearAllPoints() self.points={};self.allPoints=nil end
function M:SetFrameLevel(v) self.level=v end
function M:GetFrameLevel() return self.level or (self.parent and self.parent:GetFrameLevel()+1 or 1) end
function M:SetFrameStrata(v) self.strata=v end
function M:CreateTexture(name,layer) local o=make('Texture',name,self);o.layer=layer;return o end
function M:CreateFontString(name,layer) local o=make('FontString',name,self);o.layer=layer;return o end
function M:CreateAnimationGroup() return make('AnimationGroup',nil,self) end
function M:CreateAnimation(kind) local o=make('Animation',nil,self);o.animationType=kind;return o end
function M:SetFont(file,height,flags) assert(type(file)=='string' and type(height)=='number' and type(flags)=='string','SetFont argument contract'); self.fontSize=height; return true end
function M:SetText(text) assert(type(text)=='string' or type(text)=='number' or text==nil,'SetText argument');self.text=tostring(text or '') end
function M:GetText() return self.text or '' end
function M:SetTextColor(...) self.color={...} end
function M:SetTexture(path) assert(type(path)=='string' or type(path)=='number');self.texture=path;return true end
function M:SetColorTexture(...) self.fill={...} end
function M:SetVertexColor(...) self.vertex={...} end
function M:SetAlpha(v) self.alpha=v end
function M:SetBackdrop(v) self.backdrop=v end
function M:SetBackdropColor(...) self.bg={...} end
function M:SetBackdropBorderColor(...) self.border={...} end
function M:SetAutoFocus(v) assert(v==false,'UI stole focus');self.autofocus=v end
function M:ClearFocus() self.focus=false end
function M:SetFocus() self.focus=true end
function M:GetStringHeight() return math.ceil(#self:GetText()/math.max(1,(self.w or 300)/6))*(self.fontSize or 12)+18 end
function M:SetThumbTexture(path) if not self.thumb then self.thumb=self:CreateTexture() end;self.thumb:SetTexture(path) end
function M:GetThumbTexture() return self.thumb end
function M:SetValue(v) if self.value~=v then self.value=v;self:Fire('OnValueChanged',v) end end
function M:SetVerticalScroll(v) self.scroll=v end
function M:GetVerticalScroll() return self.scroll or 0 end
function M:SetScrollChild(v) self.child=v end
function M:Play() self.playing=true end
function M:Stop() self.playing=false end
for _,name in ipairs({'RegisterForDrag','SetClampedToScreen','SetMovable','EnableMouse','EnableMouseWheel','SetWordWrap','SetMaxLines','SetJustifyH','SetJustifyV','SetTextInsets','SetMaxBytes','SetSpacing','SetMinMaxValues','SetValueStep','SetObeyStepOnDrag','SetOrientation','SetOrigin','SetScaleFrom','SetScaleTo','SetSmoothing','SetFromAlpha','SetToAlpha','SetDuration','SetOrder','SetLooping','StartMoving','StopMovingOrSizing','SetOwner','AddLine','RegisterEvent','UnregisterEvent'}) do
    M[name]=function(self,...) self[name..'Args']={...} end
end
function CreateFrame(kind,name,parent) return make(kind,name,parent or UIParent) end
UIParent=make('Frame','UIParent',nil); UIParent:SetSize(1400,900)
GameTooltip=make('Frame','GameTooltip',UIParent)
UISpecialFrames={}; SlashCmdList={}; STANDARD_TEXT_FONT='Fonts\\FRIZQT__.TTF'
function GetLocale() return 'frFR' end
function PlaySound() mock.sounds=mock.sounds+1 end
C_Timer={After=function(_,fn) mock.timers[#mock.timers+1]=fn end,NewTicker=function(_,fn) return {Cancel=function() end,callback=fn} end}
function mock:Flush() local queued=self.timers;self.timers={};for _,fn in ipairs(queued) do fn() end end
return mock
