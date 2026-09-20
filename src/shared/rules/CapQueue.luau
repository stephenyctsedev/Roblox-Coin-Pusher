--!strict
local CapQueue = {}

function CapQueue.push(list: { any }, item: any, cap: number): any?
	table.insert(list, item)
	if #list > cap then
		return table.remove(list, 1)
	end
	return nil
end

function CapQueue.remove(list: { any }, item: any): boolean
	local index = table.find(list, item)
	if index == nil then
		return false
	end
	table.remove(list, index)
	return true
end

return CapQueue
