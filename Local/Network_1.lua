getgenv().network = network or {
    cache = {
        connections = {
            insert = function(self,value)
                self[#self + 1] = value
            end,
            clear = function(self)
                for i=1,#self do local v = self[i]
                    if type(v) ~= "function" then
                       v:Disconnect()
                       table.remove(self,table.find(self,v))
                    end
                end
            end,
        },
        remotes = {
            insert = function(self,value)
                self[#self + 1] = value
            end,
        },
    },
    Retrieve = function(self,name,func)
        local Remote = self.cache.remotes[name] or (typeof(name) == "Instance" and name) or game:FindFirstChild(name,true)
        if Remote then
            if Remote:IsA("RemoteEvent") then
                self.cache.connections:insert(Remote.OnClientEvent:Connect(func))
                self.cache.remotes[name] = Remote
            elseif Remote:IsA("RemoteFunction") then
                Remote.OnClientInvoke = func
                self.cache.connections:insert(Remote.OnClientInvoke)
                self.cache.remotes[name] = Remote
            else
                warn("Unable to Connect Network")
            end
        else
            warn("Unable to Indentify Remote Network")
        end
    end,
    Send = function(self,name,...)
        local Remote = self.cache.remotes[name] or (typeof(name) == "Instance" and name) or game:FindFirstChild(name,true)
        if Remote then
            if Remote:IsA("RemoteEvent") then
                self.cache.remotes[name] = Remote
                return Remote.FireServer(Remote,...)
            elseif Remote:IsA("RemoteFunction") then
                self.cache.remotes[name] = Remote
                return Remote.InvokeServer(Remote,...)
            else
                warn("Unable to Connect Network")
            end
        else
            warn("Unable to Indentify Remote Network")
        end
    end,
}

return network
