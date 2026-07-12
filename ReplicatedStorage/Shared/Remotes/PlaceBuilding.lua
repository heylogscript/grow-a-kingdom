local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage
end

local remoteFunction = remotesFolder:FindFirstChild("PlaceBuilding")
if not remoteFunction then
    remoteFunction = Instance.new("RemoteFunction")
    remoteFunction.Name = "PlaceBuilding"
    remoteFunction.Parent = remotesFolder
end

return remoteFunction
