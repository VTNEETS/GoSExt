--[[ QWER
	 ___  ___  _______   _______        __  ___________  __    __   
	|"  \/"  |/"     "| /"      \      /""\("     _   ")/" |  | "\  
	 \   \  /(: ______)|:        |    /    \)__/  \\__/(:  (__)  :) 
	  \\  \/  \/    |  |_____/   )   /' /\  \  \\_ /    \/      \/  
	  /\.  \  // ___)_  //      /   //  __'  \ |.  |    //  __  \\  
	 /  \   \(:      "||:  __   \  /   /  \\  \\:  |   (:  (  )  :) 
	|___/\___|\_______)|__|  \___)(___/    \___)\__|    \__|  |__/  

	- 0.01: Released.
---------------------------------------]]

require("DamageLib")
Callback.Add("Load", function()
local Enemies = {Count = 0, List = {nil, nil, nil, nil, nil}};
local XerathVer, Mode = 0.1, "";
local Ignite = myHero:GetSpellData(4).name == "SummonerDot" and HK_SUMMONER_1 or myHero:GetSpellData(5).name == "SummonerDot" and HK_SUMMONER_2 or nil
local function ManaCheck(value) return value <= myHero.mana / myHero.maxMana * 100 end
local function GetHP2(unit) return unit.health + unit.shieldAD + unit.shieldAP end
for i = 1, Game.HeroCount(), 1 do
	local enemy = Game.Hero(i);
	if enemy.team ~= myHero.team then
		Enemies.Count = Enemies.Count + 1;
		Enemies.List[Enemies.Count] = enemy;
	end
end
table.sort(Enemies, function(a, b) return a.charName < b.charName end)

local function GetOrbMode()
    if Orbwalker["Combo"].__active then return "Combo" end
    if Orbwalker["Farm"].__active then return "LaneClear" end
    if Orbwalker["LastHit"].__active then return "LastHit" end
    if Orbwalker["Harass"].__active then return "Harass" end
        return "";
end

local function AddMenu(Menu, Tbl, MP)
	local StrID, StrN = {"cb", "hr", "lc", "jc", "ks", "lh"}, {"Combo", "Harass", "LaneClear", "JungleClear", "KillSteal", "LastHit"}
	for i = 1, 6 do
		if Tbl[i] then Menu:MenuElement({id = StrID[i], name = "Use in "..StrN[i], value = true}) end
		if MP and i > 1 and Tbl[i] then Menu:MenuElement({id = "MP"..StrID[i], name = StrN[i].." if %MP >= ", value = MP, min = 1, max = 99, step = 1}) end
	end
end
------------------------- { Deftsu's time Kappa} -------------------------

local function IsReady(slot)
	return myHero:GetSpellData(slot).currentCd == 0 and myHero.mana >= myHero:GetSpellData(slot).mana and myHero:GetSpellData(slot).level > 0
end

local function IsImmune(unit)
	for i = 1, unit.buffCount, 1 do
		local buff = unit:GetBuff(i);
		if buff.count > 0 then
			if buff.name == "VladimirSanguinePool" or buff.name == "JudicatorIntervention" then return true end
			if (buff.name == "KindredRNoDeathBuff" or buff.name == "UndyingRage") and GetPercentHP(unit) <= 10 then return true end
		end
	end
		return false;
end

local function IsValidTarget(target, range)
	if not target or not target.valid or not target.visible or not target.isTargetable or IsImmune(target) then return false end
		return target.pos:DistanceTo() <= range;
end

class "TargetSelector"
function TargetSelector:__init(range, damageType, includeShields, from, focusSelected, menu, isOrb, mode)
	self.range = range or -1
	self.damageType = damageType or 1
	self.includeShields = includeShields or false
	self.from = from
	self.focusSelected = focusSelected or false
	self.Mode = mode or 1
	self.CalcDamage = function(target, DamageType, value) 
		return DamageType == 1 and CalcPhysicalDamage(myHero, target, value) or CalcMagicalDamage(myHero, target, value) 
	end
	self.IsValidTarget = function(target, range)
		if not IsValidTarget(target, range) then return false end
		if range <= 0 then return Orbwalker:InAutoAttackRange(target) end
		return true
	end
	self.sorting = {
		[1] = function(a,b) return self.CalcDamage(a, self.damageType, 100) / (1 + a.health) * self:GetPriority(a) > self.CalcDamage(b, self.damageType, 100) / (1 + b.health) * self:GetPriority(b) end,
		[2] = function(a,b) return self.CalcDamage(a, 1, 100) / (1 + a.health) * self:GetPriority(a) > self.CalcDamage(b, 1, 100) / (1 + b.health) * self:GetPriority(b) end,
		[3] = function(a,b) return self.CalcDamage(a, 2, 100) / (1 + a.health) * self:GetPriority(a) > self.CalcDamage(b, 2, 100) / (1 + b.health) * self:GetPriority(b) end,
		[4] = function(a,b) return a.health < b.health end,
		[5] = function(a,b) return a.totalDamage > b.totalDamage end,
		[6] = function(a,b) return a.ap > b.ap end,
		[7] = function(a,b) return a.pos:DistanceTo(self.from and self.from or myHero) < b.pos:DistanceTo(self.from and self.from or myHero) end
	}
	if menu then
		self.Menu = menu
		self.Menu:MenuElement({type = MENU, id = "TargetSelector", name = "Target Selector"})
		self.Menu.TargetSelector:MenuElement({type = MENU, id = "FocusTargetSettings", name = "Focus Target Settings"})
		self.Menu.TargetSelector.FocusTargetSettings:MenuElement({id = "FocusSelected", name = "Focus Selected Target", value = true})
		self.Menu.TargetSelector.FocusTargetSettings:MenuElement({id = "ForceFocusSelected", name = "Attack Only Selected Target", value = false})
		self.Menu.TargetSelector:MenuElement({id = "TargetingMode", name = "Target Mode", value = 1, drop = {"Auto Priority", "Less Attack", "Less Cast", "Lowest HP", "Most AD", "Most AP", "Closest"}, callback = function(v) self.Mode = v end})
		self.Menu.TargetSelector:MenuElement({type = SPACE})
		for i = 1, Enemies.Count, 1 do
			local enemy = Enemies.List[i]
			self.Menu.TargetSelector:MenuElement({id = enemy.charName.. "Priority", name = enemy.charName, value = self:GetDBPriority(enemy.charName), min = 1, max = 5, step = 1})
		end
		self.Menu.TargetSelector:MenuElement({id = "AutoPriority", name = "Auto Arrange Priorities", tooltip = "Resets everything to default", rightIcon = "http://i.imgur.com/QCSuX46.png", type = SPACE, onclick = function() 
			for i = 1, Enemies.Count, 1 do
				self.Menu.TargetSelector[enemy.charName.. "Priority"]:Value(self:GetDBPriority(Enemies.List[i].charName))
			end
		end})
	end
	Callback.Add("WndMsg", function(msg, key) self:WndMsg(msg, key) end)
	if isOrb then Callback.Add("Draw", function() self:Draw() end) end
end

function TargetSelector:Draw()
	if (self.Menu and self.Menu.TargetSelector.FocusTargetSettings.FocusSelected:Value() or self.focusSelected) and IsValidTarget(self.SelectedTarget) then
		Draw.Circle(self.SelectedTarget.pos, 150, 3, Draw.Color(255,255,0,0))
	end
end

function TargetSelector:WndMsg(msg, key)
	if msg == WM_LBUTTONDOWN and (self.Menu and self.Menu.TargetSelector.FocusTargetSettings.FocusSelected:Value() or self.focusSelected) then
		local target, distance = nil, math.huge
		for i = 1, Enemies.Count, 1 do
			local enemy = Enemies.List[i]
			if enemy and not enemy.dead and enemy.valid and enemy.isTargetable then
				local distance2 = enemy.pos:DistanceTo(mousePos)
				if distance2 < distance and distance2 < enemy.boundingRadius*2 then
					target = enemy
					distance = distance2
				end
			end
		end
		self.SelectedTarget = target
	end
end

function TargetSelector:SetPriority(unit, prio)
	if not self.Menu.TargetSelector[unit.charName.. "Priority"] then return end
	self.Menu.TargetSelector[unit.charName.. "Priority"]:Value(math.max(1, math.min(5, prio)))
end

function TargetSelector:GetPriority(unit)
	local prio = 1
	if self.Menu.TargetSelector[unit.charName.. "Priority"] ~= nil then
		prio = self.Menu.TargetSelector[unit.charName.. "Priority"]:Value()
	end
	if prio == 2 then
		return 1.5
	elseif prio == 3 then
		return 1.75
	elseif prio == 4 then
		return 2
	elseif prio == 5 then 
		return 2.5
	end
		return prio
end

function TargetSelector:GetDBPriority(charName)
	local p1 = {"Alistar", "Amumu", "Bard", "Blitzcrank", "Braum", "Cho'Gath", "Dr. Mundo", "Garen", "Gnar", "Hecarim", "Janna", "Jarvan IV", "Leona", "Lulu", "Malphite", "Nami", "Nasus", "Nautilus", "Nunu", "Olaf", "Rammus", "Renekton", "Sejuani", "Shen", "Shyvana", "Singed", "Sion", "Skarner", "Sona", "Taric", "TahmKench", "Thresh", "Volibear", "Warwick", "MonkeyKing", "Yorick", "Zac", "Zyra"}
	local p2 = {"Aatrox", "Darius", "Elise", "Evelynn", "Galio", "Gangplank", "Gragas", "Irelia", "Jax", "Lee Sin", "Maokai", "Morgana", "Nocturne", "Pantheon", "Poppy", "Rengar", "Rumble", "Ryze", "Swain", "Trundle", "Tryndamere", "Udyr", "Urgot", "Vi", "XinZhao", "RekSai"}
	local p3 = {"Akali", "Diana", "Ekko", "Fiddlesticks", "Fiora", "Fizz", "Heimerdinger", "Jayce", "Kassadin", "Kayle", "Kha'Zix", "Lissandra", "Mordekaiser", "Nidalee", "Riven", "Shaco", "Vladimir", "Yasuo", "Zilean"}
	local p4 = {"Ahri", "Anivia", "Annie", "Ashe", "Azir", "Brand", "Caitlyn", "Cassiopeia", "Corki", "Draven", "Ezreal", "Graves", "Jinx", "Kalista", "Karma", "Karthus", "Katarina", "Kennen", "KogMaw", "Kindred", "Leblanc", "Lucian", "Lux", "Malzahar", "MasterYi", "MissFortune", "Orianna", "Quinn", "Sivir", "Syndra", "Talon", "Teemo", "Tristana", "TwistedFate", "Twitch", "Varus", "Vayne", "Veigar", "Velkoz", "Viktor", "Xerath", "Zed", "Ziggs", "Jhin", "Soraka"}
	if table.contains(p1, charName) then return 1 end
	if table.contains(p2, charName) then return 2 end
	if table.contains(p3, charName) then return 3 end
		return table.contains(p4, charName) and 4 or 1
end

function TargetSelector:GetTarget()
	if (self.Menu and self.Menu.TargetSelector.FocusTargetSettings.FocusSelected:Value() or self.focusSelected) and self.IsValidTarget(self.SelectedTarget, self.Menu.TargetSelector.FocusTargetSettings.ForceFocusSelected:Value() and math.huge or self.range) then
		return self.SelectedTarget
	end
	local targets = {}
	local cnt = 0
	for i = 1, Enemies.Count, 1 do
		local enemy = Enemies.List[i];
		if self.IsValidTarget(enemy, self.range) then
			cnt = cnt + 1;
			targets[cnt] = enemy;
		end
	end
	if cnt > 0 then
		table.sort(targets, self.sorting[self.Mode]);
		return targets[1];
	end
	return nil;
end
-------------------------------------------------------------------------------

local RMode, mouseRange = 1, 500;
local qwerXe = MenuElement({id = "qwerXerathMenu", name = "[QWER Xerath] Version "..XerathVer, type = MENU, leftIcon = "http://ddragon.leagueoflegends.com/cdn/6.24.1/img/champion/Xerath.png"})
	qwerXe:MenuElement({id = "Q", name = "Q Settings", type = MENU, leftIcon = "http://vignette3.wikia.nocookie.net/leagueoflegends/images/5/57/Arcanopulse.png"})
		AddMenu(qwerXe.Q, {true, true, false, false, true, false}, 15)
	qwerXe:MenuElement({id = "W", name = "W Settings", type = MENU, leftIcon = "http://vignette1.wikia.nocookie.net/leagueoflegends/images/2/20/Eye_of_Destruction.png"})
		AddMenu(qwerXe.W, {true, true, false, false, true, false}, 15)
	qwerXe:MenuElement({id = "E", name = "E Settings", type = MENU, leftIcon = "http://vignette2.wikia.nocookie.net/leagueoflegends/images/6/6f/Shocking_Orb.png"})
		AddMenu(qwerXe.E, {true, true, false, false, true, false}, 15)
	qwerXe:MenuElement({id = "R", name = "R Settings", type = MENU, leftIcon = "http://vignette1.wikia.nocookie.net/leagueoflegends/images/3/37/Rite_of_the_Arcane.png"})
		qwerXe.R:MenuElement({id = "mode", name = "Choose your mode: ", value = 1, drop = {"Press Key", "Auto Cast", "Target in mouse range"}, callback = function(v) RMode = v end})
		qwerXe.R:MenuElement({id = "pk", name = "Press Key", key = string.byte("T")})
		qwerXe.R:MenuElement({id = "mR", name = "Mouse Range", value = 500, min = 200, max = 1500, step = 50, callback = function(v) mouseRange = v end})
		qwerXe.R:MenuElement({id = "c1", name = "Setting R1 Delay", value = 230, min = 0, max = 1500, step = 1})
		qwerXe.R:MenuElement({id = "c2", name = "Setting R2 Delay", value = 250, min = 0, max = 1500, step = 1})
		qwerXe.R:MenuElement({id = "c3", name = "Setting R3 Delay", value = 270, min = 0, max = 1500, step = 1})
		qwerXe.R:MenuElement({id = "c4", name = "Setting R4 Delay", value = 290, min = 0, max = 1500, step = 1})
		qwerXe.R:MenuElement({id = "c5", name = "Setting R5 Delay", value = 310, min = 0, max = 1500, step = 1})
	if Ignite then
		qwerXe:MenuElement({id = "I", name = "Ignite Settings", type = MENU, leftIcon = "http://www.nhomgamethu.com/images/upload/images/lien-minh-huyen-thoai/supports/thieu-dot.png"})
		AddMenu(qwerXe.I, {false, false, false, false, true, false})
	end
	qwerXe:MenuElement({id = "Draw", name = "Draw Settings", type = MENU, leftIcon = "http://zrajm.org/nerd/drone-colours/colour_wheel.png"})
		qwerXe.Draw:MenuElement({id = "Qcur", name = "Draw Qcurrent Range", value = true})
		qwerXe.Draw:MenuElement({id = "Qmax", name = "Draw Qmax Range", value = true})
		qwerXe.Draw:MenuElement({id = "Qcol", name = "Q color setting", color = Draw.Color(200, 27, 148, 209)})
		qwerXe.Draw:MenuElement({id = "drawW", name = "Draw W Range", value = true})
		qwerXe.Draw:MenuElement({id = "Wcol", name = "W color setting", color = Draw.Color(200, 0, 245, 255)})
		qwerXe.Draw:MenuElement({id = "drawE", name = "Draw E Range", value = true})
		qwerXe.Draw:MenuElement({id = "Ecol", name = "E color setting", color = Draw.Color(200, 186, 85, 211)})
		qwerXe.Draw:MenuElement({id = "drawR", name = "Draw R Range", value = true})
		qwerXe.Draw:MenuElement({id = "drawRmm", name = "Draw R Range on Minimap", value = true})
		qwerXe.Draw:MenuElement({id = "Rcol", name = "R color setting", color = Draw.Color(255, 0, 255, 255)})
		qwerXe.Draw:MenuElement({id = "Rkill", name = "Draw enemies killable by R", value = true})
	qwerXe:MenuElement({id = "Escape", name = "Escape Mode", type = MENU})
		qwerXe.Escape:MenuElement({id = "key", name = "Press key to enable", key = string.byte("G")})
		qwerXe.Escape:MenuElement({id = "uw", name = "Use W", value = true})
		qwerXe.Escape:MenuElement({id = "ue", name = "Use E", value = true})
-------------------------------------------------------------------------------

local QActive, RCount = false, myHero:GetSpellData(_R).level + 2
RMode = qwerXe.R.mode:Value()
mouseRange = qwerXe.R.mR:Value()
local RDelay = {0, 0, 0, 0, 0}
local Damage = {
	[0] = function(unit) return CalcMagicalDamage(myHero, unit, 40 + 40*myHero:GetSpellData(_Q).level + 0.75*myHero.ap) end,
	[1] = function(unit) return CalcMagicalDamage(myHero, unit, 45 + 45*myHero:GetSpellData(_W).level + 0.9*myHero.ap) end,
	[2] = function(unit) return CalcMagicalDamage(myHero, unit, 50 + 30*myHero:GetSpellData(_E).level + 0.45*myHero.ap) end,
	[3] = function(unit) return CalcMagicalDamage(myHero, unit, 170 + 30*myHero:GetSpellData(_R).level + 0.43*myHero.ap) end
}

local Data = {
	[0] = { range = 750,                                       speed = math.huge, delay = 1.1,  width = 180},
	[1] = { range = myHero:GetSpellData(_W).range,             speed = math.huge, delay = 0.85, width = 400},
	[2] = { range = myHero:GetSpellData(_E).range,             speed = 1500,      delay = 0.25, width = 140},
	[3] = { range = 2000 + 1200*myHero:GetSpellData(_R).level, speed = math.huge, delay = 0.72, width = 380}
}

local Ready = {
	[0] = false,
	[1] = false,
	[2] = false,
	[3] = false
}

local Target = {
	[0] = TargetSelector(1500, 2, false, nil, false, qwerXe.Q, false),
	[1] = TargetSelector(Data[1].range, 2, false, nil, false, qwerXe.W, false),
	[2] = TargetSelector(Data[2].range, 2, false, nil, false, qwerXe.E, false, false, 7)
}
-------------------------------------------------------------------------------

local function QCheck()
	for i = 1, myHero.buffCount, 1 do
		local buff = myHero:GetBuff(i);
		if buff.name == "xerathqlaunchsound" then
			if buff.count > 0 then return buff.expireTime - buff.startTime - buff.duration end
			return false;
		end
	end
		return false;
end

local function UpdateQRange()
	if not Ready[0] then return end
	local temp = QCheck()
	if temp then
		QActive = true;
		Data[0].range = math.min(1.5, temp)*500 + 750
	else
		QActive = false;
		Data[0].range = 750;
	end
end

local function GetRTarget(range)
	local RTarget, temp = nil, nil;
	for i = 1, Enemies.Count, 1 do
		local enemy = Enemies.List[i];
		if IsValidTarget(enemy, Data[3].range) and (not range or enemy.pos:DistanceTo(mousePos) <= range) then
			local temp2 = Damage[3](enemy) / GetHP2(enemy);
			if not temp or temp2 > temp then
				temp = temp2;
				RTarget = enemy;
			end
		end
	end
		return RTarget
end

local function CastR(target)
	if not IsValidTarget(target, Data[3].range) then return end

	local index = myHero:GetSpellData(3).level - RCount + 3
	if Game.Timer() - RDelay[index] >= qwerXe.R["c"..index]:Value()*0.001 then
		local pos = target:GetPrediction(Data[3].speed, Data[3].delay);
		Control.CastSpell(HK_R, pos);
	end
end

local function RCheck()
	if RMode < 3 then
		local target = GetRTarget();
		if RMode == 1 then
			if qwerXe.R.pk:Value() then CastR(target) end
		else
			CastR(target)
		end
	else
		local target = GetRTarget(mouseRange)
		CastR(target)
	end
end

local Rtemp = myHero:GetSpellData(_R).castTime
local function UpdateR()
	if not Ready[3] then return end
	local Rdata = myHero:GetSpellData(_R);
	if Rdata.name == "XerathLocusOfPower2" then
		RCount = myHero:GetSpellData(_R).level + 3;
	else
		if 2 + myHero:GetSpellData(_R).level >= RCount then RCheck() end
		if Rdata.castTime > Rtemp then
			Rtemp = Rdata.castTime
			RCount = RCount - 1
			local count = 2 + myHero:GetSpellData(_R).level
			if count == RCount then return end
			local time = Game.Timer() + 0.7
			if count == 3 then
				if RCount == 2 then
					RDelay[2] = time
				elseif RCount == 1 then
					RDelay[3] = time
				end
			elseif count == 4 then
				if RCount == 3 then
					RDelay[2] = time
				elseif RCount == 2 then
					RDelay[3] = time
				elseif RCount == 1 then
					RDelay[4] = time
				end
			elseif count == 5 then
				if RCount == 4 then
					RDelay[2] = time
				elseif RCount == 3 then
					RDelay[3] = time
				elseif RCount == 2 then
					RDelay[4] = time
				elseif RCount == 1 then
					RDelay[5] = time
				end
			end
		end
	end
end

local function CastQ(target)
	if not IsValidTarget(target, 1500) then return end
	if not QActive then
		Control.KeyDown(HK_Q);
	elseif Data[0].range >= target.pos:DistanceTo() then
		local pos = target:GetPrediction(Data[0].delay, Data[0].speed);
		Control.CastSpell(HK_Q, pos);
	end
end

local function CastW(target)
	if not IsValidTarget(target, Data[1].range) then return end
	local pos = target:GetPrediction(Data[1].delay, Data[1].speed);
	Control.CastSpell(HK_W, pos);
end

local function CastE(target)
	if not IsValidTarget(target, Data[2].range) then return end
	if target:GetCollision(Data[2].width, Data[2].speed, Data[2].delay) == 0 then
		local pos = target:GetPrediction(Data[2].speed, Data[2].delay);
		Control.CastSpell(HK_E, pos);
	end
end

local function KillSteal()
	for i = 1, Enemies.Count, 1 do
		local enemy = Enemies.List[i];
		local HP = GetHP2(enemy);
		if Ready[0] and qwerXe.W.ks:Value() and ManaCheck(qwerXe.W.MPks:Value()) and HP < Damage[0](enemy) then
			CastQ(enemy);
			return;
		end
		if Ready[1] and qwerXe.Q.ks:Value() and ManaCheck(qwerXe.Q.MPks:Value()) and HP < Damage[1](enemy) then
			CastW(enemy);
			return;
		end
		if Ready[2] and qwerXe.E.ks:Value() and ManaCheck(qwerXe.E.MPks:Value()) and HP < Damage[2](enemy) then
			CastE(enemy);
			return;
		end
		if Ignite and qwerXe.I.ks:Value() and IsValidTarget(enemy, 600) and enemy.health + enemy.hpRegen*2.5 + enemy.shieldAD < 50 + 20*myHero.levelData.lvl then
			Control.CastSpell(Ignite, enemy)
			return;
		end
	end
end

local tick = GetTickCount()
local function Escape(WTarget, ETarget)
	if tick < GetTickCount() then
		Control.Move();
		tick = GetTickCount() + 400;
	end
	if Wtarget and qwerXe.Escape.uw:Value() then
		CastW(WTarget);
		return;
	end
	if Etarget and qwerXe.Escape.ue:Value() then
		CastE(ETarget);
	end
end

Callback.Add("Tick", function()
	if myHero.dead then return end
	Ready[0] = IsReady(0);
	Ready[1] = IsReady(1);
	Ready[2] = IsReady(2);
	Ready[3] = IsReady(3);
	Data[3].range = 2000 + 1200*myHero:GetSpellData(_R).level;
	UpdateQRange();
	UpdateR();
	Mode = GetOrbMode();
	local QTarget = Ready[0] and Target[0]:GetTarget() or nil;
	local WTarget = Ready[1] and Target[1]:GetTarget() or nil;
	local ETarget = Ready[2] and Target[2]:GetTarget() or nil;
	if Mode == "Combo" then
		if WTarget and qwerXe.W.cb:Value() then CastW(WTarget) end
		if QTarget and qwerXe.Q.cb:Value() then CastQ(QTarget) end
		if ETarget and qwerXe.E.cb:Value() then CastE(ETarget) end
	end

	if Mode == "Harass" then
		if WTarget and qwerXe.W.hr:Value() and ManaCheck(qwerXe.W.MPhr:Value()) then CastW(WTarget) end
		if QTarget and qwerXe.Q.hr:Value() and (QActive or ManaCheck(qwerXe.Q.MPhr:Value())) then CastQ(QTarget) end
		if ETarget and qwerXe.E.hr:Value() and ManaCheck(qwerXe.E.MPhr:Value()) then CastE(ETarget) end
	end

	KillSteal()
	if qwerXe.Escape.key:Value() then Escape(Wtarget, ETarget) end
end)

Callback.Add("Draw", function()
	if myHero.dead then return end
	if Ready[0] then
		local color = qwerXe.Draw.Qcol:Value()
		if qwerXe.Draw.Qcur:Value() then Draw.Circle(myHero.pos, Data[0].range, 1, color) end
		if qwerXe.Draw.Qmax:Value() then Draw.Circle(myHero.pos, 1500, 1, color) end
	end
	if Ready[1] and qwerXe.Draw.drawW:Value() then
		Draw.Circle(myHero.pos, Data[1].range, 1, qwerXe.Draw.Wcol:Value())
	end
	if Ready[2] and qwerXe.Draw.drawE:Value() then
		Draw.Circle(myHero.pos, Data[2].range, 1, qwerXe.Draw.Ecol:Value())
	end
	if Ready[3] then
		local color = qwerXe.Draw.Rcol:Value()
		if qwerXe.Draw.drawR:Value() then Draw.Circle(myHero.pos, Data[3].range, 1, color) end
		if qwerXe.Draw.drawRmm:Value() then Draw.CircleMinimap(myHero.pos, Data[3].range, 1, color) end
	end
	if myHero:GetSpellData(_R).name ~= "XerathLocusOfPower2" and RMode == 3 then
		Draw.Circle(mousePos, mouseRange, 1, Draw.Color(255, 255, 255, 0))
	end
	if Ready[3] or myHero:GetSpellData(_R).name ~= "XerathLocusOfPower2" then
		local cnt = 0
		for i = 1, Enemies.Count, 1 do
			local enemy = Enemies.List[i];
			if IsValidTarget(enemy, Data[3].range) and GetHP2(enemy) < Damage[3](enemy)*RCount then
				cnt = cnt + 1;
				Draw.Text(enemy.charName.." Killable", 30, 50, 250 + cnt*35, Draw.Color(255, 255, 0, 0))
			end
		end
	end
end)
end)
