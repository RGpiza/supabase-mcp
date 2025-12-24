-- MemoryBank.lua
-- A memory management system for Cline (AI assistant)

local MemoryBank = {}

-- Memory storage
local memoryStore = {}

-- Configuration
local CONFIG = {
    MAX_MEMORY_SIZE = 1000000,  -- Maximum number of stored items
    CLEANUP_INTERVAL = 300,      -- Cleanup interval in seconds (5 minutes)
    DEFAULT_EXPIRY = 3600        -- Default expiry time in seconds (1 hour)
}

-- Utility functions
local function log(message, ...)
    print("[MemoryBank]", string.format(message, ...))
end

local function warnLog(message, ...)
    print("[MemoryBank] WARN:", string.format(message, ...))
end

-- Time management
local function getCurrentTime()
    return os.time()
end

-- Memory management
local function cleanupExpiredMemory()
    local currentTime = getCurrentTime()
    local cleanedCount = 0
    
    for key, data in pairs(memoryStore) do
        if data.expiresAt and data.expiresAt < currentTime then
            memoryStore[key] = nil
            cleanedCount = cleanedCount + 1
        end
    end
    
    if cleanedCount > 0 then
        log("Cleaned up %d expired memory entries", cleanedCount)
    end
    
    return cleanedCount
end

local function enforceMemoryLimit()
    local currentSize = 0
    for _ in pairs(memoryStore) do
        currentSize = currentSize + 1
    end
    
    if currentSize > CONFIG.MAX_MEMORY_SIZE then
        -- Remove oldest entries
        local entries = {}
        for key, data in pairs(memoryStore) do
            table.insert(entries, { key = key, timestamp = data.timestamp })
        end
        
        table.sort(entries, function(a, b)
            return a.timestamp < b.timestamp
        end)
        
        local toRemove = currentSize - CONFIG.MAX_MEMORY_SIZE
        for i = 1, toRemove do
            memoryStore[entries[i].key] = nil
        end
        
        log("Enforced memory limit - removed %d entries", toRemove)
    end
end

-- Todo management
local todos = {}

function MemoryBank.addTodo(task)
    table.insert(todos, {
        id = #todos + 1,
        task = task,
        completed = false,
        createdAt = getCurrentTime()
    })
    log("Added todo: %s", task)
    return #todos
end

function MemoryBank.completeTodo(id)
    if todos[id] and not todos[id].completed then
        todos[id].completed = true
        todos[id].completedAt = getCurrentTime()
        log("Completed todo #%d: %s", id, todos[id].task)
        return true
    end
    return false
end

function MemoryBank.removeTodo(id)
    if todos[id] then
        local task = todos[id].task
        table.remove(todos, id)
        log("Removed todo #%d: %s", id, task)
        return true
    end
    return false
end

function MemoryBank.listTodos()
    return todos
end

function MemoryBank.getTodoStats()
    local total = #todos
    local completed = 0
    for _, todo in ipairs(todos) do
        if todo.completed then
            completed = completed + 1
        end
    end
    return {
        total = total,
        completed = completed,
        pending = total - completed
    }
end

-- Public API
function MemoryBank.store(key, value, expiresAt)
    -- Validate key
    if type(key) ~= "string" or key == "" then
        warnLog("Invalid key provided: %s", tostring(key))
        return false, "Invalid key"
    end
    
    -- Validate value
    if value == nil then
        warnLog("Cannot store nil value for key: %s", key)
        return false, "Cannot store nil value"
    end
    
    -- Cleanup expired entries
    cleanupExpiredMemory()
    
    -- Enforce memory limits
    enforceMemoryLimit()
    
    -- Store the memory
    memoryStore[key] = {
        value = value,
        timestamp = getCurrentTime(),
        expiresAt = expiresAt and tonumber(expiresAt) or nil
    }
    
    log("Stored memory for key: %s", key)
    return true
end

function MemoryBank.storeWithExpiry(key, value, expirySeconds)
    local expiresAt = getCurrentTime() + (tonumber(expirySeconds) or CONFIG.DEFAULT_EXPIRY)
    return MemoryBank.store(key, value, expiresAt)
end

function MemoryBank.retrieve(key)
    local data = memoryStore[key]
    
    if not data then
        return nil
    end
    
    -- Check if expired
    if data.expiresAt and data.expiresAt < getCurrentTime() then
        memoryStore[key] = nil
        return nil
    end
    
    return data.value
end

function MemoryBank.exists(key)
    return MemoryBank.retrieve(key) ~= nil
end

function MemoryBank.delete(key)
    if not memoryStore[key] then
        return false
    end
    
    memoryStore[key] = nil
    log("Deleted memory for key: %s", key)
    return true
end

function MemoryBank.clear()
    local count = 0
    for _ in pairs(memoryStore) do
        count = count + 1
    end
    memoryStore = {}
    log("Cleared all memory (%d entries)", count)
    return true
end

function MemoryBank.listKeys()
    local keys = {}
    for key in pairs(memoryStore) do
        table.insert(keys, key)
    end
    return keys
end

function MemoryBank.getInfo()
    local totalEntries = 0
    local expiredEntries = 0
    local currentTime = getCurrentTime()
    
    for _, data in pairs(memoryStore) do
        totalEntries = totalEntries + 1
        if data.expiresAt and data.expiresAt < currentTime then
            expiredEntries = expiredEntries + 1
        end
    end
    
    return {
        totalEntries = totalEntries,
        expiredEntries = expiredEntries,
        memoryUsage = totalEntries,
        config = CONFIG,
        todoStats = MemoryBank.getTodoStats()
    }
end

-- Cleanup service
local cleanupThread = nil

function MemoryBank.startCleanupService()
    if cleanupThread then
        return false, "Cleanup service already running"
    end
    
    cleanupThread = true
    log("Starting cleanup service")
    
    -- This would be implemented with a proper threading mechanism in a real system
    -- For now, we'll just provide the function that would be called periodically
    
    return true
end

function MemoryBank.stopCleanupService()
    if not cleanupThread then
        return false, "Cleanup service not running"
    end
    
    cleanupThread = nil
    log("Stopped cleanup service")
    return true
end

-- Perform initial cleanup
cleanupExpiredMemory()

log("MemoryBank initialized")

return MemoryBank
