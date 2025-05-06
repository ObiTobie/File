local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Network = {}

function Network:Send(RemoteName, ...)
	local Remote = Remotes:FindFirstChild(RemoteName)
	if not Remote then
		warn("[Network] Remote not found:", RemoteName)
		return
	end

	if Remote:IsA("RemoteFunction") then
		return Remote:InvokeServer(...)
	elseif Remote:IsA("RemoteEvent") then
		Remote:FireServer(...)
	else
		warn("[Network] Invalid remote type:", Remote.ClassName)
	end
end

function Network:Retrieve(RemoteName, Callback)
	local Remote = Remotes:FindFirstChild(RemoteName)
	if not Remote then
		warn("[Network] Remote not found:", RemoteName)
		return
	end

	if Remote:IsA("RemoteEvent") then
		Remote.OnClientEvent:Connect(Callback)
	elseif Remote:IsA("RemoteFunction") then
		Remote.OnClientInvoke = Callback
	else
		warn("[Network] Remote type not support:", Remote.ClassName)
	end
end

getgenv().network = getgenv().network or Network
return Network
