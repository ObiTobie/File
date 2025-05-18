--[[




VYNX PLS DO NOT SKID THAT MY WORK FVCK U
discord.gg/g36syShCfC



]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
Mouse.TargetFilter = workspace:WaitForChild("PartEffect")

local Camera = Workspace.CurrentCamera
local UnitsData = require(ReplicatedStorage.Modules.UnitsData)

local CombatModule = {}
CombatModule.Settings = {
	UseBodyVelocityLook = true
}

local lastAttackTime = tick()
local comboIndex = 1

local function playAnimation(animation)
	if Player.Character and Player.Character:FindFirstChild("Humanoid") then
		local track = Player.Character.Humanoid:LoadAnimation(animation)
		track:Play(0)
		return track
	end
end

local function isGrounded()
	local origin = Player.Character.HumanoidRootPart.Position
	local direction = Vector3.new(0, -4, 0)
	local ignoreList = { workspace:WaitForChild("PlayerFodel"), workspace:WaitForChild("PartEffect"), workspace:WaitForChild("Enemy") }
	local ray = Ray.new(origin, direction)
	local part = Workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
	return part ~= nil
end

function CombatModule.BodyVelocityLook(character, speed, forceLookAtTarget)
	if not CombatModule.Settings.UseBodyVelocityLook then return end
	local target = character.Target.Value
	local velocity = Instance.new("BodyVelocity")
	velocity.MaxForce = Vector3.one * 25000
	velocity.Velocity = character.HumanoidRootPart.CFrame.LookVector * speed
	velocity.Parent = character.HumanoidRootPart
	Debris:AddItem(velocity, 0.4)

	if (not target or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter) and (not target or not forceLookAtTarget) then
		local lookVector = Camera.CFrame.LookVector
		local newLookPos = Vector3.new(lookVector.X * 900000, character.HumanoidRootPart.Position.Y, lookVector.Z * 900000)
		character.HumanoidRootPart.CFrame = CFrame.new(character.HumanoidRootPart.Position, newLookPos)
	else
		local targetPos = target.HumanoidRootPart.Position
		local lookPos = Vector3.new(targetPos.X, character.HumanoidRootPart.Position.Y, targetPos.Z)
		character.HumanoidRootPart.CFrame = CFrame.new(character.HumanoidRootPart.Position, lookPos)
	end
end

function CombatModule.StartCombat()
	if not Player.Character or not Player.Character:FindFirstChild("Humanoid") then return end
	if Player.Character:FindFirstChild("Hit") or Player.Character.Stastus.Value ~= "" then return end
	if Player.Character.Parent.Name ~= "PlayerFodel" then return end
	if Player.Character.Humanoid.Sit or Player.Character.Skill.Value or Player.Character:FindFirstChild("Death") then return end
	if Player.CharValue.Lost.Value == true then return end

	local slotValue = Player.CharValue:FindFirstChild("Slot" .. Player.Character.Onslot.Value).Units.Value
	local unitConfig = UnitsData[slotValue]

	if unitConfig then
		if tick() - lastAttackTime > unitConfig.ResetCombo and comboIndex <= #unitConfig.Animations then
			comboIndex = 1
		end

		if comboIndex <= #unitConfig.Animations and tick() - lastAttackTime > unitConfig.TimePerAttack then
			playAnimation(unitConfig.Animations[comboIndex])

			local skillUnit = game.ReplicatedFirst.SkillUnits:FindFirstChild(slotValue)
			if skillUnit then
				skillUnit.Slash.Event:Fire(Player.Character, comboIndex, slotValue, Player.Character.Target.Value)
			end

			local sound = ReplicatedStorage.Sound.Attack[slotValue]["Sound" .. comboIndex]:Clone()
			Debris:AddItem(sound, 4)
			sound.Parent = Player.Character.HumanoidRootPart
			sound:Play()

			ReplicatedStorage.Events.Combat:FireServer(slotValue, comboIndex)

			lastAttackTime = tick()
			comboIndex += 1

			-- if Player.Character.Shoot.Value then
			-- 	CombatModule.BodyVelocityLook(Player.Character, -6, true)
			-- 	Player.Character.UnlockCam.Value = true
			-- else
			-- 	CombatModule.BodyVelocityLook(Player.Character, 9)
			-- end

			-- local previousComboIndex = comboIndex
			-- local humanoid = Player.Character.Humanoid
			-- humanoid.AutoRotate = false
			-- humanoid.WalkSpeed = 4
			-- humanoid.JumpPower = 0
			-- Player.Character.Skill.Value = true

			-- task.wait(unitConfig.TimePerAttack)

			-- Player.Character.Skill.Value = false
			-- if comboIndex == previousComboIndex and Player.Character.Skill.Value == false then
			-- 	humanoid.WalkSpeed = 25
			-- 	humanoid.AutoRotate = true
			-- 	humanoid.JumpPower = 50
			-- 	Player.Character.UnlockCam.Value = false
			-- end
		end

		if comboIndex > #unitConfig.Animations and tick() - lastAttackTime > unitConfig.ComboCooldown then
			comboIndex = 1
		end
	end
end

return CombatModule
