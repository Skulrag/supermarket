ESX = nil
local HasAlreadyEnteredMarker = false
local LastZone
local CurrentAction
local CurrentActionMsg = ''
local CurrentActionData = {}
local PlayerData = {}
local itemsInit = false
local ownerInit = false
local myIdentifier

Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj)
            ESX = obj
        end)
        Citizen.Wait(0)
    end

    Citizen.Wait(5000)
    PlayerData = ESX.GetPlayerData()
    TriggerServerEvent('esx_shops:getOwners')
end)

RegisterNetEvent('esx_shops:saveOwners')
AddEventHandler('esx_shops:saveOwners', function(Owners, me)
    for k, v in pairs(Owners) do
        if (Config.Zones[v.store] ~= nil) then
            Config.Zones[v.store].Owner = v.owner
        end
    end
    myIdentifier = me
    ownerInit = true;
end)

RegisterNetEvent('esx_shops:receiveDBItems')
AddEventHandler('esx_shops:receiveDBItems', function(ShopItems)
    for k, v in pairs(ShopItems) do
        if (Config.Zones[k] ~= nil) then
            Config.Zones[k].Items = v
        end
    end

    itemsInit = true
end)

function OpenShopMenu(zone)
    local waiting = true
    local isForsale1
    local elements = {}
    ESX.TriggerServerCallback('esx_supermarket:isforsale', function(isForsale, price)
        if isForsale then
            table.insert(elements, { label = 'Acheter le magasin ' .. price .. '$', type = 'buy_shop' })
        end
        isForsale1 = isForsale
        waiting = false
    end, zone)
    while waiting do
        Citizen.Wait(10)
    end
    if isForsale1 then
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'buy_shop',
                {
                    title = _U('shop_proprio'),
                    align = 'top-left',
                    elements = elements
                }, function(data, menu)
                    if data.current.type == 'buy_shop' then
                        TriggerServerEvent('esx_shops:buy_shop', zone)
                        menu.close()
                    end
                end, function(data, menu)
                    menu.close()
                end)
    else

        TriggerServerEvent('esx_shops:requestDBItems', zone)
        while itemsInit do
            Citizen.Wait(10)
        end
        itemsInit = false

        SendNUIMessage({
            message = "show",
            clear = true
        })

        for i = 1, #Config.Zones[zone].Items, 1 do
            local item = Config.Zones[zone].Items[i]

            if item.limit == -1 then
                item.limit = 100
            end

            SendNUIMessage({
                message = "add",
                item = item.item,
                label = item.label,
                price = item.price,
                max = item.limit,
                loc = zone
            })

        end

        ESX.SetTimeout(200, function()
            SetNuiFocus(true, true)
        end)
    end
end

function OpenProprioMenu(zone)
    local waiting = true
    TriggerServerEvent('esx_shops:requestDBItems', zone)
    local elements = {
        { label = 'Voir les stocks', type = 'items_stock' },
        { label = 'Remplir les stocks', type = 'items_fill' },
    }
    ESX.TriggerServerCallback('esx_supermarket:isforsale', function(isForsale, _)
        if isForsale then
            table.insert(elements, { label = 'Ne plus vendre le magasin', type = 'not_forsale_anymore' })
        else
            table.insert(elements, { label = 'Vendre le magasin', type = 'sell_shop' })
        end
        waiting = false
    end, zone)
    while waiting do
        Citizen.Wait(10)
    end
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'stocks_menu',
            {
                title = _U('shop_proprio'),
                align = 'top-left',
                elements = elements
            }, function(data, menu)
                if data.current.type == 'items_stock' then
                    OpenGetStocksMenu(zone)
                elseif data.current.type == 'items_fill' then
                    OpenPutStocksMenuShop(zone)
                elseif data.current.type == 'not_forsale_anymore' then
                    TriggerServerEvent('esx_supermarket:cancelselling', zone)
                    menu.close()
                    OpenProprioMenu(zone)
                elseif data.current.type == 'sell_shop' then
                    menu.close()
                    ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'sell_shop', {
                        title = 'Prix de la vente'
                    }, function(data2, menu2)
                        local price = tonumber(data2.value)

                        if price == nil or price < 0 then
                            ESX.ShowNotification(_U('quantity_invalid'))
                        else
                            menu2.close()
                            TriggerServerEvent('esx_supermarket:putforsale', zone, price)
                            OpenProprioMenu(zone)
                        end
                    end, function(_, menu2)
                        menu2.close()
                    end)
                end
            end, function(_, menu)
                menu.close()
            end)
end

function OpenGetStocksMenu(zone)
    local elements = {
        head = { 'Nom', 'Quantité', 'Prix à l\'unité' },
        rows = {}
    }

    for i = 1, #Config.Zones[zone].Items, 1 do
        local item = Config.Zones[zone].Items[i]
        table.insert(elements.rows, {
            data = item,
            cols = {
                item.label,
                item.quantity,
                item.price
            }
        })
    end
    ESX.UI.Menu.Open('list', GetCurrentResourceName(), 'stock_menu_list',
            elements, function(data, menu)
            end, function(_, menu)
                menu.close()
            end)
end

function OpenPutStocksMenuShop(zone)
    ESX.TriggerServerCallback('esx_shops:getPlayerInventory', function(inventory)

        local elements = {}

        for i = 1, #inventory.items, 1 do
            local item = inventory.items[i]

            if item.count > 0 then
                table.insert(elements, {
                    label = item.label .. ' x' .. item.count,
                    type = 'item_standard',
                    value = item.name
                })
            end
        end
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'stock_menu_shop',
                {
                    title = 'Inventaire',
                    align = 'top-left',
                    elements = elements
                }, function(data, menu)
                    if data.current.type == 'item_standard' then
                        local itemName = data.current.value

                        ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'item_stock_quantity', {
                            title = 'Quantité'
                        }, function(dataQuantity, menuQuantity)
                            local quantity = tonumber(dataQuantity.value)

                            if quantity == nil or quantity < 0 then
                                ESX.ShowNotification(_U('quantity_invalid'))
                            else
                                menuQuantity.close()
                                ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'item_stock_price', {
                                    title = 'Prix'
                                }, function(dataPrice, menuPrice)
                                    local price = tonumber(dataPrice.value)

                                    if price == nil or price < 0 then
                                        ESX.ShowNotification(_U('quantity_invalid'))
                                    else
                                        menu.close()
                                        menuPrice.close()
                                        TriggerServerEvent('esx_shops:addItem', itemName, quantity, price, zone)
                                    end
                                end, function(_, menuPrice)
                                    menuPrice.close()
                                end)
                            end
                        end, function(_, menuQuantity)
                            menuQuantity.close()
                        end)
                    end
                end, function(_, menu)
                    menu.close()
                end)
    end)
end

AddEventHandler('esx_shops:hasEnteredMarker', function(zone)
    TriggerServerEvent('esx_shops:getOwners')
    CurrentAction = 'shop_menu'
    CurrentActionMsg = _U('press_menu')
    CurrentActionData = { zone = zone }
end)

AddEventHandler('esx_shops:hasExitedMarker', function(_)
    CurrentAction = nil
    ESX.UI.Menu.CloseAll()
end)

-- Create Blips
Citizen.CreateThread(function()
    while not ownerInit do
        Citizen.Wait(10)
    end
    for _, v in pairs(Config.Zones) do
        for i = 1, #v.Pos, 1 do
            local blip = AddBlipForCoord(v.Pos[i].x, v.Pos[i].y, v.Pos[i].z)
            SetBlipSprite(blip, 52)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, 0.7)
            SetBlipColour(blip, 2)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(_U('shops'))
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- Enter / Exit marker events
Citizen.CreateThread(function()
    while not ownerInit do
        Citizen.Wait(10)
    end
    while true do
        Citizen.Wait(10)
        local coords = GetEntityCoords(GetPlayerPed(-1))
        local isInMarker = false
        local currentZone

        for k, v in pairs(Config.Zones) do
            for i = 1, #v.Pos, 1 do
                if (GetDistanceBetweenCoords(coords, v.Pos[i].x, v.Pos[i].y, v.Pos[i].z, true) < Config.Size.x) then
                    isInMarker = true
                    ShopItems = v.Items
                    currentZone = k
                    LastZone = k
                end
            end
        end
        if isInMarker and not HasAlreadyEnteredMarker then
            HasAlreadyEnteredMarker = true
            TriggerEvent('esx_shops:hasEnteredMarker', currentZone)
        end
        if not isInMarker and HasAlreadyEnteredMarker then
            HasAlreadyEnteredMarker = false
            TriggerEvent('esx_shops:hasExitedMarker', LastZone)
        end
    end
end)

-- Key Controls
Citizen.CreateThread(function()
    while not ownerInit do
        Citizen.Wait(10)
    end
    while true do
        Citizen.Wait(10)

        if CurrentAction ~= nil then

            SetTextComponentFormat('STRING')
            AddTextComponentString(CurrentActionMsg)
            DisplayHelpTextFromStringLabel(0, 0, 1, -1)

            if CurrentAction == 'shop_menu' then
                if IsControlJustReleased(0, 38) then
                    if Config.Zones[CurrentActionData.zone].Owner == myIdentifier then
                        OpenProprioMenu(CurrentActionData.zone)
                    else
                        OpenShopMenu(CurrentActionData.zone)
                    end
                    CurrentAction = nil
                end
            elseif IsControlJustReleased(0, 44) then
                ESX.SetTimeout(200, function()
                    SetNuiFocus(false, false)
                end)
            else
                Citizen.Wait(500)
            end
        end
    end
end)

function closeGui()
    SetNuiFocus(false, false)
    SendNUIMessage({ message = "hide" })
end

RegisterNUICallback('quit', function(data, cb)
    closeGui()
    cb('ok')
end)

RegisterNUICallback('purchase', function(data, cb)
    TriggerServerEvent('esx_shops:buyItem', data.item, data.count, data.loc)
    cb('ok')
end)
