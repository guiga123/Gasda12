--[[

   _   _   _   _   _   _   _     _   _   _   _   _   _  
  / \ / \ / \ / \ / \ / \ / \   / \ / \ / \ / \ / \ / \ 
 ( S | u | p | p | o | r | t ) ( B | u | n | d | l | e )
  \_/ \_/ \_/ \_/ \_/ \_/ \_/   \_/ \_/ \_/ \_/ \_/ \_/ 

]]


local SupportHeroes = {
	Karma = true,
}


if not SupportHeroes[myHero.charName] then return end

local ver = "20170406001"

require "DamageLib"



require "GoSWalk"



local GPred = _G.gPred

if not GoSWalk.Version or GoSWalk.Version < 0.36 then
	PrintChat("GoSWalk is outdated. Please update it before using script")
	
	return
end

	function CountAllyNearPos(pos, range)
		if pos == nil or not range then return 0 end
		local c = 0
		if not myHero.dead then
			if GetDistance(pos) <= range then
				c = c+ 1
			end
		end
		
		for k,v in pairs(GetAllyHeroes()) do 
		if v and GetOrigin(v) ~= nil and not IsDead(v) and GetDistanceSqr(pos,GetOrigin(v)) < range*range then
			c = c + 1
		end
		end
		return c
	end
	
local Spells = {}

class "Karma"
--so lazy
local Q,W,E,R = nil,nil,nil,nil

function Karma:__init()
	Q = {ready = false, range = 950, radius = 70, speed = 1700, delay = 0.25, type = "line"}
	W = {ready = false, range = 700 }
	E = {ready = false, range = 800 }
	R = {ready = false}
	self.HasMantra = false
	self.lastTick = 0
	self.SelectedTarget = nil
	self.RootBuff = nil
	self:LoadMenu()
	Callback.Add("UpdateBuff", function(u,s) self:UpdateBuff(u,s) end)
	Callback.Add("RemoveBuff", function(u,s) self:RemoveBuff(u,s) end)
	Callback.Add("ProcessSpell",function(u,s) self:ProcessSpell(u,s) end)
	--Callback.Add("CreateObj",function(o) self:CreateObj(o) end)
	Callback.Add("Tick",function() self:Tick() end)
	Callback.Add("Draw",function() self:Draw() end)
	Callback.Add("WndMsg",function(Msg, Key) self:WndMsg(Msg, Key) end)
end

function Karma:LoadMenu()
	self.Menu = Menu( "SB"..myHero.charName, "Karma - The Guardian Angel")
	self.Menu:SubMenu("Key", "> Key Settings")
	self.Menu.Key:KeyBinding("Combo","Combo",32)
	self.Menu.Key:KeyBinding("Harass","Harass",string.byte("C"))
	self.Menu.Key:KeyBinding("LaneClear","Lane Clear",string.byte("V"))
	self.Menu.Key:KeyBinding("JungleClear","Jungle Clear",string.byte("G"))
	
	self.Menu:SubMenu("Qset", "> Q Settings")
	self.Menu.Qset:Boolean("Combo","Use in Combo", true)
	self.Menu.Qset:Boolean("Harass","Use in Harass", true)
	self.Menu.Qset:Boolean("LaneClear","Use in LaneClear", true)
	self.Menu.Qset:Boolean("JungleClear","Use in JungleClear", true)
	

	self.Menu:SubMenu("Wset", "> W Settings")
	self.Menu.Wset:Boolean("Combo","Use in Combo", true)
	self.Menu.Wset:Boolean("Harass","Use in Harass", false)
	self.Menu.Wset:Boolean("JungleClear","Use in JungleClear", true)
	
	self.Menu:SubMenu("Eset", "> E Settings")
	self.Menu.Eset:Boolean("Combo","Use in Combo", true)
	self.Menu.Eset:Slider("nAlly","Min Allies Around",3,1,5)
	self.Menu.Eset:Boolean("JungleClear","Use in JungleClear", true)
	--self.Menu.Eset:Boolean("Interrupt","Interrupt Enemy Spells", true)
	self.Menu.Eset:Boolean("Turret","Shield Against Turrets", true)
	self.Menu.Eset:Boolean("Spell","Shield Against Spells", true)
	
	
	self.Menu:SubMenu("Rset", "> R Settings")
	self.Menu.Rset:Boolean("Combo","Use in Combo", true)
	self.Menu.Rset:Boolean("LaneClear","Use in LaneClear", true)
	self.Menu.Rset:Boolean("JungleClear","Use in JungleClear", true)
	
	--self.Menu.Rset:Boolean("Interrupt","Interrupt Enemy Spells", true)
	
	
	self.Menu:SubMenu("AG", "> AntiGapcloser")
	AddGapcloseEvent(_W,W.range,true,self.Menu.AG)
	
	self.Menu:SubMenu("KS", "> KillSteal Settings")
	self.Menu.KS:Boolean("Q","Use Q",true)
	self.Menu.KS:Boolean("W","Use W",true)
	
		self.Menu:SubMenu("Draw", "> Draw Settings")
	self.Menu.Draw:Boolean("Q","Draw Q Range", true)
	self.Menu.Draw:Boolean("W","Draw W Range", true)
	self.Menu.Draw:Boolean("E","Draw E Range", true)
	self.Menu.Draw:Boolean("Root","Draw Root Time", true)
	
	PrintChat("Support Series:"..myHero.charName.." Loaded")

end

function Karma:Check()
	Q.ready = myHero:GetSpellData(_Q).level > 0 and myHero:CanUseSpell(_Q) == READY and true or false
	W.ready = myHero:GetSpellData(_W).level > 0 and myHero:CanUseSpell(_W) == READY and true or false
	E.ready = myHero:GetSpellData(_E).level > 0 and myHero:CanUseSpell(_E) == READY and true or false
	R.ready = myHero:GetSpellData(_R).level > 0 and myHero:CanUseSpell(_R) == READY and true or false
end

function Karma:GetTarget()
	if self.SelectedTarget then
		return self.SelectedTarget
	end	
	return GetCurrentTarget()
end

function Karma:ProcessSpell(unit,spell)
	if unit and unit.team ~= myHero.team and unit.type == "obj_AI_Turret" and spell.target and GetDistance(spell.target) < E.range and spell.target.type == myHero.type and spell.target.health/spell.target.maxHealth < 0.8 then
		if self.Menu.Eset.Turret:Value() and E.ready then
			myHero:CastSpell(_E,spell.target)
		end
	end
	
	if unit and unit.team ~= myHero.team and unit.type == myHero.type and spell.target and spell.target.type == myHero.type and GetDistance(spell.target) < E.range and spell.target.health/spell.target.maxHealth < 0.8  then
		if E.ready and not self.HasMantra then 
			myHero:CastSpell(_E,spell.target)
		end
	end
	

	if unit.team == 300 and spell.target and spell.target.team == myHero.team and  GetDistance(spell.target) < E.range and not self.HasMantra then
		if E.ready and self.Menu.Eset.JungleClear:Value() and not self.HasMantra then
			myHero:CastSpell(_E,spell.target)
		end	
	end
end

function Karma:UpdateBuff(unit,buff)
	if unit.isMe then
		--print(buff.Name)
	end
	if unit.team ~= myHero.team and buff.Name:lower():find("karma") then
		--print(buff.Name)
	end
	if unit.isMe and buff.Name:lower() == "karmamantra" then
		self.HasMantra = true
	end
	if unit.team ~= myHero.team and buff.Name:lower() == "karmaspiritbind" then
		
		self.RootBuff = {time = GetGameTimer() + 2, unit = unit }
	end
end

function Karma:RemoveBuff(unit,buff)
	if unit.isMe and buff.Name:lower() == "karmamantra" then
		self.HasMantra = false
	end
	if unit.team ~= myHero.team and buff.Name:lower() == "karmaspiritbind" then
		self.RootBuff[unit.networkID] = nil
	end
end


function Karma:Tick()
	if os.clock()*1000 < self.lastTick then
		return 
	end
	self.lastTick = os.clock()*1000 + 1
	self:Check()
	if self.SelectedTarget and self.SelectedTarget.dead then 
		self.SelectedTarget = nil
	end
	--self:
	if self.Menu.KS.W:Value() and W.ready then
		self:KillSteal()
	end
	if self.HasMantra then
		Q.range = 1150
	else
		Q.range = 950
	end

	if self.Menu.Key.Combo:Value() then
		self:Combo()
	end
	if self.Menu.Key.Harass:Value() then
		self:Harass()
	end
	if self.Menu.Key.LaneClear:Value() then
		self:LaneClear()
	end
	if self.Menu.Key.JungleClear:Value() then
		self:JungleClear()
	end
	if E.ready and self.Menu.Eset.Spell:Value() and _G.GoSEvade ~= nil then
		for i,ally in pairs(GetAllyHeroes()) do
			if GetDistance(ally) < E.range and not ally.dead and _G.GoSEvade:IsInSkillShots(ally,ally.pos,0,2) then
				myHero:CastSpell(_E,ally)
			end
		end
	end	

end

function Karma:GetShieldTarget()
	local result = myHero
	local total = CountAllyNearPos(myHero.pos,660)
	for i, ally in pairs(GetAllyHeroes()) do
		if ally and not ally.dead and ally.charName ~= myHero.charName and GetDistance(ally) <= E.range then
			local count = CountAllyNearPos(ally.pos,660)
			if count > total then
				total = count
				result = ally
			end
		end
	end
	if total >= self.Menu.Eset.nAlly:Value() then
		return result
	else
		return nil
	end	
end

function Karma:CollisitionCheck(pos)
	local objects = {}
	for _,minion in pairs(minionManager.objects) do
		if minion.team ~= myHero.team and ValidTarget(minion,1200) then
			local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(myHero.pos, pos, Vector(minion))
			if isOnSegment and GetDistance(pointSegment,minion) < Q.radius + minion.boundingRadius then
				table.insert(objects,minion)
			end
		end
	end
	return #objects > 0, objects
end

function Karma:Combo()
	
	local target = self:GetTarget()
	if ValidTarget(target) then
		if GetDistance(target) < W.range then
			myHero:CastSpell(_W,target)
		end
		if GetDistance(target) < Q.range + 150 then
			if R.ready and self.Menu.Rset.Combo:Value() then
				--print("use R")
				myHero:CastSpell(_R,myHero)
			end
			if Q.ready and GPred then
				local qPred = GPred:GetPrediction(target,myHero,Q)
				if qPred.HitChance >= 3  then
					local col,obj = self:CollisitionCheck(qPred.CastPosition)
					if not col then
						myHero:CastSpell(_Q,qPred.CastPosition.x,qPred.CastPosition.z)
					else
						table.sort(obj,function(x,y) return GetDistance(x) < GetDistance(y) end)
			
							if GetDistance(target) <= GetDistance(obj[1]) or (self.HasMantra and GetDistance(target,obj[1]) < 200) then
								myHero:CastSpell(_Q,qPred.CastPosition.x,qPred.CastPosition.z)
							end
						
					end
				end
			elseif Q.ready then
				local qPred = GetPrediction(target,Q)
				if qPred.hitChance > 0.1 then
					local col,obj = self:CollisitionCheck(qPred.castPos)
					if not col then
						myHero:CastSpell(_Q,qPred.castPos.x,qPred.castPos.z)
					else
						table.sort(obj,function(x,y) return GetDistance(x) < GetDistance(y) end)
			
							if GetDistance(target) <= GetDistance(obj[1]) or (self.HasMantra and GetDistance(target,obj[1]) < 200) then
								myHero:CastSpell(_Q,qPred.castPos.x,qPred.castPos.z)
							end
						
					end
				end
			end	
		end
	end
	if E.ready and self.Menu.Eset.Combo:Value() then
		local ally = self:GetShieldTarget()
		if ally and R.ready then
			myHero:CastSpell(_R,myHero)
		end
		if self.HasMantra then	
			myHero:CastSpell(_E,ally)
		end
	end
end

function Karma:KillSteal()

end

function Karma:Harass()

end

function Karma:LaneClear()
	local pos,hit = GetFarmPosition(Q.range,2*Q.radius,300-myHero.team)
	if pos and hit >= 1 then
		if hit > 1 and R.ready and self.Menu.Rset.LaneClear:Value() then
			myHero:CastSpell(_R,myHero)
		end
		--if hit > 1 and self.HasMantra then
		if self.Menu.Qset.LaneClear:Value() then
			myHero:CastSpell(_Q,pos.x,pos.z)
		end
	end
end

function Karma:JungleClear()
	local mobs = {}
	for _,mob in pairs(minionManager.objects) do
		if mob and not mob.dead and mob.team == 300 and ValidTarget(mob,Q.range) then
			table.insert(mobs,mob)
		end
	end
	if #mobs < 1 then return end
	table.sort(mobs,function(a,b) return a.maxHealth > b.maxHealth end)
	local mob = mobs[1]
	if mob then
		
		if Q.ready and GetDistance(mob) < Q.range and self.Menu.Qset.JungleClear:Value() then
			if R.ready and self.Menu.Rset.JungleClear:Value() then
				myHero:CastSpell(_R,myHero)
			end	
			myHero:CastSpell(_Q,mob.x,mob.z)
		end
		if W.ready and GetDistance(mob) < W.range and self.Menu.Wset.JungleClear:Value() then
			myHero:CastSpell(_W,mob)
		end
		if E.ready and not self.HasMantra then
			local eTarget = myHero
			--for i,ally in pa
			--myHero:CastSpell(_E,)
		end
	end
	
end


function Karma:Draw()
	if myHero.dead then return end
	if self.Menu.Draw.Root:Value() and self.RootBuff then
		local info = self.RootBuff
			if info and ValidTarget(info.unit) and info.time > GetGameTimer() then
				local dif = info.time - GetGameTimer()
				DrawText3D(tostring(string.format("%.1f", dif)), info.unit.x, info.unit.y, info.unit.z, 30, ARGB(240, 255, 255, 255), true)	
			end
		
	end
	if self.Menu.Draw.Q:Value() then
		local qcolor = Q.ready and  ARGB(240,30,144,255) or ARGB(240,255,0,0)
		DrawCircle3D(myHero.x,myHero.y,myHero.z,Q.range,1,qcolor,20)
	end
	if self.Menu.Draw.W:Value() then
		local wcolor = W.ready and  ARGB(240,30,144,255) or ARGB(240,255,0,0)
		DrawCircle3D(myHero.x,myHero.y,myHero.z,W.range,1,wcolor,20)
	end
	if self.Menu.Draw.E:Value() then
		local ecolor = E.ready and  ARGB(240,30,144,255) or ARGB(240,255,0,0)
		DrawCircle3D(myHero.x,myHero.y,myHero.z,E.range,1,ecolor,20)
	end
end

function Karma:WndMsg(msg,key)
	if msg == 513 then
		local minD = math.huge
		local starget = nil
		for i, enemy in pairs(GetEnemyHeroes()) do
			if ValidTarget(enemy) then
				if GetDistance(enemy, GetMousePos()) <= minD or starget == nil then
					minD = GetDistance(enemy, GetMousePos())
					starget = enemy
				end
			end
		end
		
		if starget and minD < 200 then
			if self.SelectedTarget and starget.charName == self.SelectedTarget.charName then
				self.SelectedTarget = nil
				PrintChat("<font color=\"#FF0000\">Deselected target: "..starget.charName.."</font>")
			else
				self.SelectedTarget = starget
				PrintChat("<font color=\"#ff8c00\">New target selected: "..starget.charName.."</font>")
			end
		end
	
	end

end


DelayAction(function()
_G[myHero.charName]()
end,0.5)

if AutoUpdateScript then
AutoUpdateScript("Support Bundle",ver,"raw.githubusercontent.com","/KeVuong/GoS/master/Support.version","/KeVuong/GoS/master/Support%20Bundle.lua", SCRIPT_PATH.."Support Bundle.lua")
end
