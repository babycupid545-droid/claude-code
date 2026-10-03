--!strict
-- Optional art. Anything placed in ReplicatedStorage.Assets is used; anything missing falls
-- back to simple generated shapes, so the game is always playable. See docs/ASSETS.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = {}

function Assets.folder(name: string): Instance?
	local root = ReplicatedStorage:FindFirstChild("Assets")
	return if root then root:FindFirstChild(name) else nil
end

-- Children of Assets/<folder> sorted by name, so every client picks the same one for an index.
function Assets.list(name: string): { Instance }
	local folder = Assets.folder(name)
	if not folder then
		return {}
	end
	local items = folder:GetChildren()
	table.sort(items, function(a, b)
		return a.Name < b.Name
	end)
	return items
end

function Assets.find(folderName: string, itemName: string): Instance?
	local folder = Assets.folder(folderName)
	return if folder then folder:FindFirstChild(itemName) else nil
end

return Assets
