return function(ns,test)
    test('UTF-8 display sanitation and canonical identities',function()
        assert(ns.Util.Clean('|Tevil:40|t\nÉlodie',9)=='Tevil:40t')
        assert(ns.Util.Clean('abéz',3)=='ab')
        assert(ns.Util.Clean('abéz',4)=='abé')
        assert(ns.Util.Name('fantine','Les Sentinelles')=='Fantine-lessentinelles')
        assert(not ns.Util.Name('|Hbad','Realm'))
        assert(ns.Util.Name('ÉLÉONORE-Les Sentinelles','Realm')==ns.Util.Name('éléonore-lessentinelles','Realm'))
    end)
    test('Independent randomness and serializable generator state',function()
        local a,b=ns.Util.RNG(913),ns.Util.RNG(913)
        for i=1,100 do ns.Util.Token('card'); assert(a:Int(1000)==b:Int(1000)) end
        local c=ns.Util.RNG(a.state); assert(c:Int(27)==a:Int(27))
    end)
    test('Demo uses isolated session clients and completes game/revenge at four and eight',function()
        for _,n in ipairs({4,8}) do
            local demo=ns.Demo.New(n,function() end,function() end)
            assert(#demo.clients==n)
            local view=demo.clients[1]:GetView()
            assert(view.phase=='ACTIVE',view.phase)
            assert(view.private and view.private.role)
            for _,client in ipairs(demo.clients) do
                assert(not client.state or client.id==view.hostId)
                local v=client:GetView()
                for _,p in ipairs(v.players) do
                    assert(p.role==nil)
                    for _,slot in ipairs(p.slots) do assert(not slot.face) end
                end
            end
            for i=1,100 do
                if demo.clients[1]:GetView().phase=='GAME_OVER' then break end
                demo:Next()
            end
            assert(demo.clients[1]:GetView().phase=='GAME_OVER')
            local old=demo.clients[1]:GetView().gameId
            demo:Next(); demo:Next()
            assert(demo.clients[1]:GetView().gameId~=old)
            assert(demo.clients[1]:GetView().phase=='ACTIVE')
            assert(demo.clients[1]:GetView().previousHolderId==nil)
            demo:Perspective(); assert(demo:Current()==demo.clients[2])
            demo:Close(); assert(not demo.clients[1]:GetView())
        end
    end)
end
