local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players: Players = game:GetService("Players")
local VirtualInputManager: VirtualInputManager = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local Modules: Folder? = ReplicatedStorage:WaitForChild("Modules")
local Net: ModuleScript = Modules:WaitForChild("Net")
local Enemies: Folder = workspace:WaitForChild("Enemies")
local Characters: Folder = workspace:WaitForChild("Characters")
local Boats: Folder = workspace:WaitForChild("Boats")
local Module = {}
local HIDDEN_SETTINGS: { [string]: any } = {
	SKILL_COOLDOWN = 0.5,
	CLEAR_AFTER = 50
}

local function CreateNewClear()
	local COUNT_NEWINDEX = 0

	return {
		__newindex = function(self, index, value)
			if COUNT_NEWINDEX >= HIDDEN_SETTINGS.CLEAR_AFTER then
				for key, cache in pairs(self) do
					if typeof(cache) == "Instance" and not cache:IsDescendantOf(game) then
						rawset(self, key, nil)
					end
				end
				COUNT_NEWINDEX = 0
			end

			COUNT_NEWINDEX += 1
			return rawset(self, index, value)
		end
	}
end
local SeaBeasts: Folder = workspace:WaitForChild("SeaBeasts")
local function CheckPlayerAlly(__Player: Player): boolean
	if tostring(__Player.Team) == "Marines" and __Player.Team == Player.Team then
		return false
	elseif __Player:HasTag(`Ally{Player.Name}`) or Player:HasTag(`Ally{__Player.Name}`) then
		return false
	end

	return true
end
Module.AttackCooldown = 0
local Cached = {
	Closest = nil,
	Equipped = nil,
	Humanoids = setmetatable({}, CreateNewClear()),
	Enemies = {}, -- setmetatable({}, CreateNewClear()),
	Progress = {},
	Bring = {},
	Tools = {}
}
function Module.IsAlive(Character)
	if Character then
		local Humanoids = Cached.Humanoids
		local Humanoid = Humanoids[Character] or Character:FindFirstChild("Humanoid")

		if not Humanoid and Character.Parent == Boats then
			return true
		elseif Character.Parent == SeaBeasts then
			Humanoid = Character:FindFirstChild("Health")
		end

		if Humanoid then
			if not Humanoids[Character] then
				Humanoids[Character] = Humanoid
			end

			return Humanoid[if Humanoid.ClassName == "Humanoid" then "Health" else "Value"] > 0
		end
	end
end
Module.FastAttack = (function()
	local FastAttack = {
		Distance = 65,
		attackMobs = true,
		attackPlayers = false,
		Equipped = nil,
		Debounce = 0,
		ComboDebounce = 0,
		ShootDebounce = 0,
		M1Combo = 0,

		HitboxLimbs = {"RightLowerArm", "RightUpperArm", "LeftLowerArm", "LeftUpperArm", "RightHand", "LeftHand"}
	}

	local RE_RegisterAttack = Net:WaitForChild("RE/RegisterAttack")
	local RE_RegisterHit = Net:WaitForChild("RE/RegisterHit")
	local Events = ReplicatedStorage:WaitForChild("Events")

	local SUCCESS_FLAGS, COMBAT_REMOTE_THREAD = pcall(function()
		return require(Modules.Flags).COMBAT_REMOTE_THREAD or false
	end)


	local HIT_FUNCTION; task.defer(function()
		local PlayerScripts = Player:WaitForChild("PlayerScripts")
		local LocalScript = PlayerScripts:FindFirstChildOfClass("LocalScript")

		while not LocalScript do
			Player.PlayerScripts.ChildAdded:Wait()
			LocalScript = PlayerScripts:FindFirstChildOfClass("LocalScript")
		end

		if getsenv then
			local Success, ScriptEnv = pcall(getsenv, LocalScript)

			if Success and ScriptEnv then
				HIT_FUNCTION = ScriptEnv._G.SendHitsToServer
			end
		end
	end)

	local IsAlive = Module.IsAlive


	local function ExpandsHitBox(Enemies)
		for i = 1, #Enemies do
			Enemies[i][2].Size = Vector3.one * 50
			Enemies[i][2].Transparency = 1
		end
	end

	function FastAttack:CheckStun(ToolTip: string, Character: Character, Humanoid: Humanoid): boolean
		local Stun = Character:FindFirstChild("Stun")
		local Busy = Character:FindFirstChild("Busy")

		if Humanoid.Sit and (ToolTip == "Sword" or ToolTip == "Melee" or ToolTip == "Gun") then
			return false
			-- elseif Stun and Stun.Value > 0 then {{ or Busy and Busy.Value }}
			--	 return false
		end

		return true
	end

	function FastAttack:Process(assert: boolean, Enemies: Folder, BladeHits: table, Position: Vector3, Distance: number): (nil)
		if not assert then return end

		local HitboxLimbs = self.HitboxLimbs
		local Mobs = Enemies:GetChildren()

		for i = 1, #Mobs do
			local Enemy = Mobs[i]
			local BasePart = Enemy:FindFirstChild(HitboxLimbs[math.random(#HitboxLimbs)]) or Enemy.PrimaryPart

			if not BasePart then continue end

			local CanAttack = Enemy.Parent == Characters and CheckPlayerAlly(Players:GetPlayerFromCharacter(Enemy))

			if Enemy ~= Player.Character and (Enemy.Parent ~= Characters or CanAttack) then
				if IsAlive(Enemy) and (Position - BasePart.Position).Magnitude <= Distance then
					if not self.EnemyRootPart then
						self.EnemyRootPart = BasePart
					else
						table.insert(BladeHits, { Enemy, BasePart })
					end
				end
			end
		end
	end

	function FastAttack:GetAllBladeHits(Character: Character, Distance: number?): (nil)
		local Position = Character:GetPivot().Position
		local BladeHits = {}
		Distance = Distance or self.Distance

		self:Process(self.attackMobs, Enemies, BladeHits, Position, Distance)
		--self:Process(self.attackPlayers, Characters, BladeHits, Position, Distance)

		return BladeHits
	end

	function FastAttack:GetClosestEnemy(Character: Character, Distance: number?): (nil)
		local BladeHits = self:GetAllBladeHits(Character, Distance)

		local Distance, Closest = math.huge

		for i = 1, #BladeHits do
			local Magnitude = if Closest then (Closest.Position - BladeHits[i][2].Position).Magnitude else Distance

			if Magnitude <= Distance then
				Distance, Closest = Magnitude, BladeHits[i][2]
			end
		end

		return Closest
	end

	function FastAttack:GetGunHits(Character: Character, Distance: number?)
		local BladeHits = self:GetAllBladeHits(Character, Distance)
		local GunHits = {}

		for i = 1, #BladeHits do
			if not GunHits[1] or (BladeHits[i][2].Position - GunHits[1].Position).Magnitude <= 10 then
				table.insert(GunHits, BladeHits[i][2])
			end
		end

		return GunHits
	end

	function FastAttack:GetCombo(): number
		local Combo = if tick() - self.ComboDebounce <= 0.4 then self.M1Combo else 0
		Combo = if Combo >= 4 then 1 else Combo + 1

		self.ComboDebounce = tick()
		self.M1Combo = Combo

		return Combo
	end

	function FastAttack:UseFruitM1(Character: Character, Equipped: Tool, Combo: number): (nil)
		local Position = Character:GetPivot().Position
		local EnemyList = Enemies:GetChildren()

		for i = 1, #EnemyList do
			local Enemy = EnemyList[i]
			local PrimaryPart = Enemy.PrimaryPart
			if IsAlive(Enemy) and PrimaryPart and (PrimaryPart.Position - Position).Magnitude <= 50 then
				local Direction = (PrimaryPart.Position - Position).Unit
				return Equipped.LeftClickRemote:FireServer(Direction, Combo)
			end
		end
	end

	function FastAttack:UseNormalClick(Humanoid: Humanoid, Character: Character, Cooldown: number): (nil)
		self.EnemyRootPart = nil
		local BladeHits = self:GetAllBladeHits(Character)
		local EnemyHitBox = self.EnemyRootPart

		if EnemyHitBox then
			if SUCCESS_FLAGS and COMBAT_REMOTE_THREAD and HIT_FUNCTION then
				RE_RegisterAttack:FireServer(Cooldown)
				HIT_FUNCTION(EnemyHitBox, BladeHits)
			elseif SUCCESS_FLAGS and not COMBAT_REMOTE_THREAD then
				RE_RegisterAttack:FireServer(Cooldown)
				RE_RegisterHit:FireServer(EnemyHitBox, BladeHits)
			else
				table.insert(BladeHits, { Enemy, EnemyHitBox })
				ExpandsHitBox(BladeHits)

				VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1);task.wait(0.05)
				VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
			end
		end
	end


	function FastAttack.attack()
		if (tick() - Module.AttackCooldown) <= 1 then return end
		if not IsAlive(Player.Character) then return end

		local self = FastAttack
		local Character = Player.Character
		local Humanoid = Character.Humanoid

		local Equipped = Character:FindFirstChildOfClass("Tool")
		local ToolTip = Equipped and Equipped.ToolTip
		local ToolName = Equipped and Equipped.Name

		if not Equipped or (ToolTip ~= "Gun" and ToolTip ~= "Melee" and ToolTip ~= "Blox Fruit" and ToolTip ~= "Sword") then
			return nil
		end

		local Cooldown = Equipped:FindFirstChild("Cooldown") and Equipped.Cooldown.Value or 0.3

		if (tick() - self.Debounce) >= Cooldown and self:CheckStun(ToolTip, Character, Humanoid) then
			local Combo = self:GetCombo()
			Cooldown += if Combo >= 4 then 0.05 else 0

			self.Equipped = Equipped
			self.Debounce = if Combo >= 4 and ToolTip ~= "Gun" then (tick() + 0.05) else tick()

			return self:UseNormalClick(Humanoid, Character, Cooldown)
		end
	end

	return FastAttack
end)()

return Module
