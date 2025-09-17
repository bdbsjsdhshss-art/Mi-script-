-- ConveyorSpawner (Server)
-- Colocar en ServerScriptService

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config
local ConveyorFolder = Workspace:FindFirstChild("ConveyorSpawn") -- plantillas
local SpawnArea = Workspace:FindFirstChild("ConveyorSpawnPoint") -- opcional: un Part que marca centro de spawn
local OutputFolderName = "ConveyorItems"
local MIN_SPAWN_INTERVAL = 3
local MAX_SPAWN_INTERVAL = 7
local MAX_ITEMS = 12 -- límite de ítems visibles en la cinta

-- Remotes (opcional, si prefieres que el ProximityPrompt invoque el Remote)
local remotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
local RE_Buy = remotesFolder and remotesFolder:FindFirstChild("BuyBrainrot")

-- crear carpeta de salida
local conveyorItems = Workspace:FindFirstChild(OutputFolderName)
if not conveyorItems then
    conveyorItems = Instance.new("Folder")
    conveyorItems.Name = OutputFolderName
    conveyorItems.Parent = Workspace
end

-- obtener lista de plantillas
local templates = {}
if ConveyorFolder then
    for _, v in pairs(ConveyorFolder:GetChildren()) do
        if v:IsA("Model") then
            table.insert(templates, v)
        end
    end
end

-- util: elegir template aleatorio
local function chooseTemplate()
    if #templates == 0 then return nil end
    return templates[math.random(1, #templates)]
end

-- util: calcular posición de spawn (alrededor del SpawnArea o zona aleatoria)
local function pickPosition()
    if SpawnArea and SpawnArea:IsA("BasePart") then
        local radius = 10
        local angle = math.random() * math.pi * 2
        local r = math.random() * radius
        local pos = SpawnArea.Position + Vector3.new(math.cos(angle) * r, 2, math.sin(angle) * r)
        return pos
    else
        -- fallback: cerca del origen
        local pos = Vector3.new(math.random(-20,20), 3, math.random(-20,20))
        return pos
    end
end

-- función que maneja compra cuando alguien usa el ProximityPrompt (server-side)
local function onPromptTriggered(player, templateName)
    -- Puedes usar el RemoteEvent existente para centralizar la lógica:
    if RE_Buy then
        -- FireServer no se puede usar desde servidor; mejor llamar la misma lógica interna.
        -- Para simplicidad, dispararemos el RemoteEvent "BuyBrainrot" con el player (si el código del server espera OnServerEvent).
        -- Pero RemoteEvent:FireServer sólo funciona desde cliente. En su lugar, replicamos lógica mínima:
        -- Aquí haremos una petición "simulada" a la misma función que RE_Buy.OnServerEvent usa en tu otro script.
        -- Para mantenerlo simple y evitar duplicar lógicas complejas, simplemente emitimos un StealResult informativo:
        local resultRem = remotesFolder and remotesFolder:FindFirstChild("StealResult")
        if resultRem then
            resultRem:FireClient(player, false, "Compra por ProximityPrompt: usa la tienda GUI para comprar (demostración).")
        end
        return
    end
    -- If no remote: notify
    local resultRem = remotesFolder and remotesFolder:FindFirstChild("StealResult")
    if resultRem then
        resultRem:FireClient(player, false, "Compra por ProximityPrompt: tienda desconectada.")
    end
end

-- Crear un ProximityPrompt en el clone para "comprar"
local function attachPromptToClone(clone, templateName)
    -- buscar un part para adjuntar (PrimaryPart o primera BasePart)
    local attachPart = clone.PrimaryPart
    if not attachPart then
        for _, descendant in ipairs(clone:GetDescendants()) do
            if descendant:IsA("BasePart") then
                attachPart = descendant
                break
            end
        end
    end
    if not attachPart then return end

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Comprar"
    prompt.ObjectText = templateName
    prompt.RequiresLineOfSight = false
    prompt.HoldDuration = 0.5
    prompt.MaxActivationDistance = 10
    prompt.Parent = attachPart

    -- Conexión server-side cuando el jugador activa el prompt
    prompt.Triggered:Connect(function(player)
        pcall(onPromptTriggered, player, templateName)
    end)
end

-- Spawn loop
spawn(function()
    while true do
        local waitTime = math.random(MIN_SPAWN_INTERVAL, MAX_SPAWN_INTERVAL)
        wait(waitTime)

        -- limpiar si hay demasiados items
        if #conveyorItems:GetChildren() >= MAX_ITEMS then
            -- borrar el más antiguo (primero)
            local children = conveyorItems:GetChildren()
            table.sort(children, function(a,b) return a:GetAttribute("SpawnTime") < b:GetAttribute("SpawnTime") end)
            if children[1] then children[1]:Destroy() end
        end

        local templ = chooseTemplate()
        if templ then
            local clone = templ:Clone()
            clone.Name = templ.Name .. "_Spawn"
            -- ubicar posición
            local pos = pickPosition()
            -- intentar setear PrimaryPartPosition si existe PrimaryPart
            if clone.PrimaryPart then
                clone:SetPrimaryPartCFrame(CFrame.new(pos) * CFrame.Angles(0, math.rad(math.random(0,360)), 0))
            else
                -- si no hay PrimaryPart, mover cada BasePart relativo:
                for _, part in ipairs(clone:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CFrame = CFrame.new(pos + Vector3.new(0, 1 + math.random(), 0))
                        break
                    end
                end
            end

            clone.Parent = conveyorItems
            clone:SetAttribute("TemplateName", templ.Name)
            clone:SetAttribute("SpawnTime", tick())

            attachPromptToClone(clone, templ.Name)

            -- opcional: hacer que el clone desaparezca después de X segundos si nadie lo compra
            delay(45, function()
                if clone and clone.Parent then
                    clone:Destroy()
                end
            end)
        end
    end
end)
