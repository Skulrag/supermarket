ESX = nil
local ShopItems = {}
local Shops = {}

TriggerEvent('esx:getSharedObject', function(obj)
    ESX = obj
end)

function LoadShop(zone)
    local itemResult = MySQL.Sync.fetchAll('SELECT * FROM `items`')
    local shopItemsResult = MySQL.Sync.fetchAll('SELECT * FROM `shops_items` WHERE `store`=@zone', { ['@zone'] = zone })

    local itemInformation = {}
    for i = 1, #itemResult, 1 do

        if itemInformation[itemResult[i].name] == nil then
            itemInformation[itemResult[i].name] = {}
        end

        itemInformation[itemResult[i].name].label = itemResult[i].label
        itemInformation[itemResult[i].name].limit = itemResult[i].limit
    end

    ShopItems[zone] = {}
    for i = 1, #shopItemsResult, 1 do
        if itemInformation[shopItemsResult[i].item].limit == -1 then
            itemInformation[shopItemsResult[i].item].limit = 30
        end

        if shopItemsResult[i].quantity > 0 then
            table.insert(ShopItems[zone], {
                label = itemInformation[shopItemsResult[i].item].label,
                item = shopItemsResult[i].item,
                price = shopItemsResult[i].price,
                limit = itemInformation[shopItemsResult[i].item].limit,
                quantity = shopItemsResult[i].quantity
            })
        end
    end
end

RegisterServerEvent('esx_shops:getOwners')
AddEventHandler('esx_shops:getOwners', function()
    local _source = source
    local shopListResult = MySQL.Sync.fetchAll('SELECT * FROM `shops_list`')
    for i = 1, #shopListResult, 1 do
        Shops[shopListResult[i].store] = {
            store = shopListResult[i].store,
            owner = shopListResult[i].owner,
            price = shopListResult[i].price,
            forsale = shopListResult[i].forsale
        }
    end
    local xPlayer = ESX.GetPlayerFromId(_source)
    TriggerClientEvent('esx_shops:saveOwners', _source, Shops, xPlayer.identifier)
end)

RegisterServerEvent('esx_shops:requestDBItems')
AddEventHandler('esx_shops:requestDBItems', function(zone)
    local _source = source
    LoadShop(zone)
    TriggerClientEvent('esx_shops:receiveDBItems', _source, ShopItems)
end)

RegisterServerEvent('esx_shops:buyItem')
AddEventHandler('esx_shops:buyItem', function(itemName, amount, zone)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local sourceItem = xPlayer.getInventoryItem(itemName)
    local xOwner = ESX.GetPlayerFromIdentifier(Shops[zone].owner)
    amount = ESX.Round(amount)

    -- is the player trying to exploit?
    if amount < 0 then
        print('esx_shops: ' .. xPlayer.identifier .. ' attempted to exploit the shop!')
        return
    end

    local itemLabel = ''
    local result = MySQL.Sync.fetchAll('SELECT `quantity`, `price` FROM `shops_items` WHERE store = @store AND item = @item', { ['@store'] = zone, ['@item'] = itemName })
    local price = result[1].price
    local quantity = result[1].quantity
    -- can the player afford this item?
    if xPlayer.getMoney() >= price then
        -- can the player carry the said amount of x item?
        if sourceItem ~= nil and sourceItem.limit ~= -1 and (sourceItem.count + amount) > sourceItem.limit then
            TriggerClientEvent('esx:showNotification', _source, _U('player_cannot_hold'))
        else
            --Does shop have enough items
            if quantity < amount then
                TriggerClientEvent('esx:showNotification', _source, _U('not_enough_items'))
            else
                xPlayer.removeMoney(price * amount)
                xPlayer.addInventoryItem(itemName, amount)
                xOwner.addAccountMoney('bank', price * amount)
                if result[1] then
                    MySQL.Sync.execute('UPDATE `shops_items` SET `quantity`=@quantity WHERE store = @zone AND item = @item', {
                        ['@quantity'] = quantity - amount,
                        ['@zone'] = zone,
                        ['@item'] = itemName
                    }, function(_)
                    end)
                end
                TriggerClientEvent('esx:showNotification', _source, _U('bought', amount, itemLabel, (price * amount)))
            end
        end
    else
        local missingMoney = price - xPlayer.getMoney()
        TriggerClientEvent('esx:showNotification', _source, _U('not_enough', missingMoney))
    end
end)

RegisterServerEvent('esx_shops:buy_shop')
AddEventHandler('esx_shops:buy_shop', function(zone)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local playerMoney = xPlayer.getMoney()
    local xOwner = ESX.GetPlayerFromIdentifier(Shops[zone].owner)

    if playerMoney > Shops[zone].price then
        MySQL.Sync.execute('UPDATE `shops_list` SET `price`=0, `owner`=@identifier, `forsale`=@forsale WHERE store = @zone', {
            ['@identifier'] = xPlayer.identifier,
            ['@forsale'] = false,
            ['@zone'] = zone,
        }, function(_)
        end)
        xPlayer.removeMoney(Shops[zone].price)
        xOwner.addAccountMoney('bank', Shops[zone].price)
        TriggerClientEvent('esx:showNotification', _source, 'Vous venez d\'acheter le shop au prix de ' .. Shops[zone].price .. '$')
    else
        TriggerClientEvent('esx:showNotification', _source, 'Vous n\'avez pas assez d\'argent ')
    end
end)

RegisterServerEvent('esx_shops:addItem')
AddEventHandler('esx_shops:addItem', function(itemName, quantity, price, zone)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    quantity = ESX.Round(quantity)
    price = ESX.Round(price)
    -- is the player trying to exploit?
    if quantity < 0 or price < 0 then
        print('esx_shops: ' .. xPlayer.identifier .. ' attempted to exploit the shop!')
        return
    end
    xPlayer.removeInventoryItem(itemName, quantity)
    local result = MySQL.Sync.fetchAll('SELECT `quantity` FROM `shops_items` WHERE store = @store AND item = @item', { ['@store'] = zone, ['@item'] = itemName })
    if result[1] == nil then
        MySQL.Sync.execute('INSERT INTO `shops_items`(`store`, `price`, `quantity`, `item`) VALUES (@zone, @price, @quantity, @item)', {
            ['@quantity'] = 0 + quantity,
            ['@zone'] = zone,
            ['@item'] = itemName,
            ['@price'] = price
        }, function(_)
        end)
    else
        MySQL.Sync.execute('UPDATE `shops_items` SET `quantity`=@quantity, `price`=@price WHERE store = @zone AND item = @item', {
            ['@quantity'] = result[1].quantity + quantity,
            ['@zone'] = zone,
            ['@item'] = itemName,
            ['@price'] = price
        }, function(_)
        end)
    end
end)

ESX.RegisterServerCallback('esx_supermarket:isforsale', function(source, cb, zone)
    cb(Shops[zone].forsale, Shops[zone].price)
end)

RegisterServerEvent('esx_supermarket:cancelselling')
AddEventHandler('esx_supermarket:cancelselling', function(zone)
    Shops[zone].forsale = false
    MySQL.Sync.execute('UPDATE `shops_list` SET `forsale`=@forsale WHERE store = @zone', {
        ['@forsale'] = false,
        ['@zone'] = zone,
    }, function(_)
    end)
end)

RegisterServerEvent('esx_supermarket:putforsale')
AddEventHandler('esx_supermarket:putforsale', function(zone, price)
    Shops[zone].forsale = true
    MySQL.Sync.execute('UPDATE `shops_list` SET `forsale`=@forsale, `price`=@price WHERE store = @zone', {
        ['@forsale'] = true,
        ['@zone'] = zone,
        ['@price'] = price
    }, function(_)
    end)
end)

ESX.RegisterServerCallback('esx_shops:getPlayerInventory', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local items = xPlayer.inventory

    cb({
        items = items,
    })
end)

RegisterServerEvent('esx_shops:getStockItem')
AddEventHandler('esx_shops:getStockItem', function(type, itemName, count, storing)
    local xPlayer = ESX.GetPlayerFromId(source)

    xPlayer.addInventoryItem(itemName, count)
    TriggerClientEvent('esx:showNotification', _source, _U('have_withdrawn', count, inventoryItem.label)
    )
end)

