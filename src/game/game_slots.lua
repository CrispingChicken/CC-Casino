-- todo:
-- transition frames for smoother animated slots
-- Connect a printer that will produce a balance slip owed to the player if the bankChest could not pay all
-- Simulate 1000 plays and see if a profit or loss is made
-- Not printing when bank balance is too low - when it used to print due to a bug it was breaking

-- Load this computers config
local config = dofile("config.lua")

-- Peripherals
local monitor = config.monitor
local speaker = config.speaker
local printer = config.printer
local withdrawalStorage = config.withdrawalStorage
local depositStorage = config.depositStorage
local balanceStorage = config.balanceStorage
local bankStorage = config.bankStorage
local printerStorage = config.printerStorage

-- Betting config
local balanceType = config.balanceType
local balanceName = config.balanceName
local balanceImage = config.balanceImage
local gameId = config.gameId
local betAmount = config.betAmount
local bankThreshold = config.bankThreshold

-- Redstone input locations
local PLAY_REDSTONE_SIDE = "left"
local WITHDRAW_REDSTONE_SIDE = "right"

function MoveItems(fromChest, toChest, itemName, count)
    -- For some reason you need the chest name for the 'to chest'
    local toChestName = peripheral.getName(toChest)
    local totalTransferred = 0

    for slot, item in pairs(fromChest.list()) do
        if totalTransferred >= count then
            break
        end

        if item.name == itemName then
            local remaining = count - totalTransferred
            totalTransferred = totalTransferred + fromChest.pushItems(toChestName, slot, remaining)
        end
    end

    return totalTransferred
end

-- Move balance from one chest to another. Assumes that the chest only contains diamonds for balance
function MoveBalance(fromChest, toChest, count)
    return MoveItems(fromChest, toChest, balanceType, count)
end

-- Get number of items in the chest
function GetStorageItemCount(chest, itemName)
    local count = 0
    for _, item in pairs(chest.list()) do
        if item.name == itemName then
            count = count + item.count
        end
    end
    return count
end

-- Get the balance of a chest
function GetBalance(chest)
    return GetStorageItemCount(chest, balanceType)
end

-- Generate unique identifier string
function GenerateUniqueIdentifier()
    local template = 'xx-xxxx'
    local randomID = string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
    return randomID
end

-- Returns true on success else false
function PrintBalanceOwedNote(printer, amount, balanceName, uniqueIdentifier)
    if printer.newPage() then
        printer.setCursorPos(1, 1)
        printer.write("Owed: " .. amount .. " " .. balanceName)
        printer.setCursorPos(1, 2)
        printer.write("Provide slip to casino")
        printer.setCursorPos(1, 3)
        printer.write("admin")
        printer.setCursorPos(1, 4)
        printer.write("Ref: " .. uniqueIdentifier)
        printer.endPage()
        return true
    end
    return false
end

function WriteBalanceOwedFile(amount, balanceName, uniqueIdentifier, printSuccessful)
    local folderName = "owedBalances"
    local fileName = uniqueIdentifier
    if fs.exists(folderName) == false then
        fs.makeDir(folderName)
    end

    local file = fs.open(folderName .. "/" .. fileName, "a")
    file.writeLine("Owe player " .. amount .. " " .. balanceName)
    if printSuccessful then
        file.writeLine("Print successful")
    else
        file.writeLine("Print failed")
    end
end

-- The printer has to transfer its prints to the printer chest using a pipe such as one provided by mekanism
function ProcessBalanceOwed(gameIdStr, amount, balanceName, printer, printerChest, withdrawalStorage)
    local uniqueIdentifier = gameIdStr .. "-" .. GenerateUniqueIdentifier()
    local printState = PrintBalanceOwedNote(printer, amount, balanceName, uniqueIdentifier)
    -- Wait enough time for the printed not to transport to the printer chest
    sleep(1.0)
    -- If print was successful, move the note to the withdrawal storage for the player to keep
    if printState == true then
        MoveItems(printerChest, withdrawalStorage, itemName, GetStorageItemCount(itemName))
    end

    WriteBalanceOwedFile(amount, balanceName, uniqueIdentifier, printState)
end

-- Move credits from the depositStorage into the balanceChest and then count and display. Returns false for withdrawal and true for play
function EnterCreditsScene(depositStorage, balanceChest, gameName, betAmount)
    local balanceImg = paintutils.loadImage(balanceImage)
    local imageW, imageH = 10, 8
    local info = "Click button to play"
    local betAmountStr = "Bet Amount: " .. betAmount
    local w, h = term.getSize()
    local cx = w/2
    local posY = (h / 2) - (imageH / 2) + 2
    local textY = (h / 2) + 1

    -- Clear background
    paintutils.drawFilledBox(0, 0, w, h, colors.black)
    -- Draw game name, info and bet amount
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.cyan)
    term.setCursorPos(cx - (#gameName / 2) + 1, 1)
    print(gameName)
    term.setCursorPos(cx - (#info / 2) + 1, 2)
    print(info)
    term.setCursorPos(cx - (#betAmountStr / 2) + 1, 3)
    print(betAmountStr)

    while (redstone.getInput(PLAY_REDSTONE_SIDE) == false and redstone.getInput(WITHDRAW_REDSTONE_SIDE) == false) or GetBalance(balanceChest) < betAmount do
        -- Move all deposit storage credits into balance chest
        local depositStorageCredits = GetBalance(depositStorage)
        MoveBalance(depositStorage, balanceChest, depositStorageCredits)

        local numDiamonds = GetBalance(balanceChest)
        local numDiamondsStr = "x " .. numDiamonds
        local strLength = #numDiamondsStr
        local totalWidth = imageW + strLength + 1
        local startXImage = cx - (totalWidth / 2)

        -- Clear background but only after the text
        paintutils.drawFilledBox(1, 4, w, h, colors.black)
        paintutils.drawImage(balanceImg, startXImage, posY)

        local startXText = startXImage + imageW + 1
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.cyan)
        term.setCursorPos(startXText, textY + 1)
        print(numDiamondsStr)

        sleep(0.1)
    end

    if redstone.getInput(WITHDRAW_REDSTONE_SIDE) then
        return false
    end

    return true
end

function EnterBankAdminScene(bankChest, threshold)
    local balanceImg = paintutils.loadImage(balanceImage)
    local imageW, imageH = 10, 8
    local w, h = term.getSize()
    local imgX = (w / 2) - (imageW / 2)
    local imgY = (h / 2) - (imageH / 2)

    -- Clear background
    paintutils.drawFilledBox(0, 0, w, h, colors.red)
    term.setBackgroundColor(colors.red)
    term.setTextColor(colors.black)
    term.setCursorPos(1, 1)
    print("ADMIN REQUIRED")
    term.setCursorPos(1, 2)
    print("Bank balance is too low to play")
    paintutils.drawImage(balanceImg, imgX, imgY)

    -- Poll bank balance
    while GetBalance(bankChest) < threshold do
        sleep(0.3)
    end
end

-- Images
local cherryImg = paintutils.loadImage("slot_cherry.nfp")
local lemonImg = paintutils.loadImage("slot_lemon.nfp")
local grapeImg = paintutils.loadImage("slot_grape.nfp")
local sevenImg = paintutils.loadImage("slot_seven.nfp")

-- Consts
local SLOT_START_Y = 3
local SLOT_WIDTH = 8
local SLOT_HEIGHT = 15
local SLOT_IMG_WIDTH = 6
local SLOT_IMG_HEIGHT = 4
local ID_EMPTY = 0
local ID_CHERRY = 1
local ID_LEMON = 2
local ID_GRAPE = 3
local ID_SEVEN = 4

-- Contains the slot layouts for each slot (they must be different so that you don't win 3 horizontals at a time)
local SLOTS = {
    { ID_EMPTY, ID_CHERRY, ID_EMPTY, ID_LEMON, ID_EMPTY, ID_GRAPE, ID_EMPTY, ID_SEVEN },
    { ID_EMPTY, ID_LEMON, ID_EMPTY, ID_CHERRY, ID_EMPTY, ID_SEVEN, ID_EMPTY, ID_GRAPE },
    { ID_EMPTY, ID_GRAPE, ID_EMPTY, ID_LEMON, ID_EMPTY, ID_SEVEN, ID_EMPTY, ID_CHERRY }
}

term.redirect(monitor)
monitor.clear()
local w, h = term.getSize()
local csx = math.floor((w / 2) - (SLOT_WIDTH / 2)) + 1 -- center spinner x
local lsx = csx - SLOT_WIDTH - 1
local rsx = csx + SLOT_WIDTH + 1

function GetImage(index)
    if index == ID_CHERRY then
        return cherryImg
    elseif index == ID_LEMON then
        return lemonImg
    elseif index == ID_GRAPE then
        return grapeImg
    elseif index == ID_SEVEN then
        return sevenImg
    end
end

-- Draw a slot column. index: the position within the win tiles, slotX: position x (y is always SLOT_START_Y)
function DrawSlot(index, slot, slotX, colour)
    -- Calculate what should be in each draw index
    local drawIndex0 = (index % #SLOTS[slot]) + 1
    local drawIndex1 = ((index + 1) % #SLOTS[slot]) + 1
    local drawIndex2 = ((index + 2) % #SLOTS[slot]) + 1
    local tileX = slotX + 1
    local tileStartY = SLOT_START_Y + 1
    paintutils.drawFilledBox(slotX, SLOT_START_Y, slotX + SLOT_WIDTH, SLOT_START_Y + SLOT_HEIGHT, colour)
    if SLOTS[1][drawIndex0] ~= ID_EMPTY then
        paintutils.drawImage(GetImage(SLOTS[slot][drawIndex0]), tileX, tileStartY)
    end
    if SLOTS[2][drawIndex1] ~= ID_EMPTY then
        paintutils.drawImage(GetImage(SLOTS[slot][drawIndex1]), tileX, tileStartY + SLOT_IMG_HEIGHT + 1)
    end
    if SLOTS[3][drawIndex2] ~= ID_EMPTY then
        paintutils.drawImage(GetImage(SLOTS[slot][drawIndex2]), tileX, tileStartY + SLOT_IMG_HEIGHT + SLOT_IMG_HEIGHT + 2)
    end
end

function IsFruit(slotType)
    if slotType == ID_CHERRY or slotType == ID_LEMON or slotType == ID_GRAPE then
        return true
    end
end

function UpdateBalance()
    -- Draw balance and bet amount
    paintutils.drawLine(1, 1, w, 1, colors.orange)
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.orange)
    term.setTextColor(colors.black)
    local balance = GetBalance(balanceStorage)
    print("Balance: " .. balance .. ", Bet: " .. betAmount)
    return balance
end

function ResolveTypeMultiplier(slotType)
    if slotType == ID_EMPTY then
        return 0.0
    end
    if slotType == ID_LEMON then
        return 1.0
    end
    if slotType == ID_GRAPE then
        return 2.0
    end
    if slotType == ID_CHERRY then
        return 3.0
    end
    if slotType == ID_SEVEN then
        return 5.0
    end

    term.write("ERROR: No multiplier for slot type: ", slotType)
    return 0.0
end

-- Start each slot at a random location
local slot0Index = math.random(1, #SLOTS[1])
local slot1Index = math.random(1, #SLOTS[2])
local slot2Index = math.random(1, #SLOTS[3])

-- return true if balance remains, else false
function Play()
    -- Clear background
    paintutils.drawFilledBox(0, 0, w, h, colors.orange)

    -- Prize line
    paintutils.drawLine(1, h/2 + 1, w, h/2 + 1, colors.red)

    -- Draw slots background now to prevent screen flash
    DrawSlot(slot0Index, 1, lsx, 128)
    DrawSlot(slot1Index, 2, csx, 256)
    DrawSlot(slot2Index, 3, rsx, 128)

    -- Draw balance and bet amount
    local balance = UpdateBalance()

    -- Check balance
    if balance < betAmount then
        term.setCursorPos(1, 2)
        print("Not enough balance")
        sleep(5)
        return false
    end

    -- Consume balance
    MoveBalance(balanceStorage, bankStorage, betAmount)
    balance = balance - betAmount
    UpdateBalance()

    -- Spin all 3 slots
    local numSpins = math.random(10, 20)
    for i = 1,numSpins do
        slot0Index = slot0Index + 1
        slot1Index = slot1Index + 1
        slot2Index = slot2Index + 1
        DrawSlot(slot0Index, 1, lsx, 128)
        DrawSlot(slot1Index, 2, csx, 256)
        DrawSlot(slot2Index, 3, rsx, 128)
        speaker.playNote("bass", 1.0, 4)
        speaker.playNote("bass", 1.0, 8)
        speaker.playNote("bass", 1.0, 12)
        sleep(0.1)
    end

    -- Spin remaining 2 slots
    numSpins = math.random(5, 15)
    for i = 1,numSpins do
        slot1Index = slot1Index + 1
        slot2Index = slot2Index + 1
        DrawSlot(slot1Index, 2, csx, 256)
        DrawSlot(slot2Index, 3, rsx, 128)
        speaker.playNote("bass", 1.0, 8)
        speaker.playNote("bass", 1.0, 12)
        sleep(0.1)
    end

    -- Spin last slot
    numSpins = math.random(5, 15)
    for i = 1,numSpins do
        slot2Index = slot2Index + 1
        DrawSlot(slot2Index, 3, rsx, 128)
        speaker.playNote("bass", 1.0, 12)
        sleep(0.1)
    end

    term.setBackgroundColor(colors.black)

    -- Check for prize
    -- First resolve each column tile
    local slot0row0 = SLOTS[1][(slot0Index % #SLOTS[1]) + 1]
    local slot0row1 = SLOTS[1][((slot0Index + 1) % #SLOTS[1]) + 1]
    local slot0row2 = SLOTS[1][((slot0Index + 2) % #SLOTS[1]) + 1]
    local slot1row0 = SLOTS[2][(slot1Index % #SLOTS[2]) + 1]
    local slot1row1 = SLOTS[2][((slot1Index + 1) % #SLOTS[2]) + 1]
    local slot1row2 = SLOTS[2][((slot1Index + 2) % #SLOTS[2]) + 1]
    local slot2row0 = SLOTS[3][(slot2Index % #SLOTS[3]) + 1]
    local slot2row1 = SLOTS[3][((slot2Index + 1) % #SLOTS[3]) + 1]
    local slot2row2 = SLOTS[3][((slot2Index + 2) % #SLOTS[3]) + 1]

    -- Store all the lines in this array so that we can render them later with pulsating colours
    local lines = {}

    -- Column/row centers
    local c0 = lsx + (SLOT_WIDTH / 2)
    local c1 = csx + (SLOT_WIDTH / 2)
    local c2 = rsx + (SLOT_WIDTH / 2)
    local r0 = SLOT_START_Y + (SLOT_HEIGHT / 4)
    local r1 = SLOT_START_Y + ((SLOT_HEIGHT / 4) * 2) + 1
    local r2 = SLOT_START_Y + ((SLOT_HEIGHT / 4) * 3) + 2
    local win = 0

    -- Row matching
    -- Row 0
    if slot0row0 ~= ID_EMPTY and slot1row0 ~= ID_EMPTY and slot2row0 ~= ID_EMPTY then
        if slot0row0 == slot1row0 and slot0row0 == slot2row0 then
            -- top row win - you get 2x your bet * slot multiplier
            win = win + (betAmount * 2 * ResolveTypeMultiplier(slot0row0))
            table.insert(lines, {x = c0, y = r0, ex = c2, ey = r0})
        elseif IsFruit(slot0row0) and IsFruit(slot1row0) and IsFruit(slot2row0) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + betAmount
            table.insert(lines, {x = c0, y = r0, ex = c2, ey = r0})
        end
    end
    -- Row 1
    if slot0row1 ~= ID_EMPTY and slot1row1 ~= ID_EMPTY and slot2row1 ~= ID_EMPTY then
        if slot0row1 == slot1row1 and slot0row1 == slot2row1 then
            -- middle row win - you get 5x your bet
            win = win + (betAmount * 5  * ResolveTypeMultiplier(slot0row1))
            table.insert(lines, {x = c0, y = r1, ex = c2, ey = r1})
        elseif IsFruit(slot0row1) and IsFruit(slot1row1) and IsFruit(slot2row1) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + betAmount
            table.insert(lines, {x = c0, y = r1, ex = c2, ey = r1})
        end
    end
    -- Row 2
    if slot0row2 ~= ID_EMPTY and slot1row2 ~= ID_EMPTY and slot2row2 ~= ID_EMPTY then
        if slot0row2 == slot1row2 and slot0row2 == slot2row2 then
            -- bottom row win - you get 2x your bet
            win = win + (betAmount * 2 * ResolveTypeMultiplier(slot0row2))
            table.insert(lines, {x = c0, y = r2, ex = c2, ey = r2})
        elseif IsFruit(slot0row2) and IsFruit(slot1row2) and IsFruit(slot2row2) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + betAmount
            table.insert(lines, {x = c0, y = r2, ex = c2, ey = r2})
        end
    end

    -- Diagonal matching
    -- Top left to bottom right
    if slot0row0 ~= ID_EMPTY and slot1row1 ~= ID_EMPTY and slot2row2 ~= ID_EMPTY then
        if slot0row0 == slot1row1 and slot0row0 == slot2row2 then
            -- top left to bottom right win - you get 3x your bet
            win = win + (betAmount * 3 * ResolveTypeMultiplier(slot0row0))
            table.insert(lines, {x = c0, y = r0, ex = c2, ey = r2})
        elseif IsFruit(slot0row0) and IsFruit(slot1row1) and IsFruit(slot2row2) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + betAmount
            table.insert(lines, {x = c0, y = r0, ex = c2, ey = r2})
        end
    end
    -- Bottom left to top right
    if slot0row2 ~= ID_EMPTY and slot1row1 ~= ID_EMPTY and slot0row2 ~= ID_EMPTY then
        if slot0row2 == slot1row1 and slot0row2 == slot2row0 then
            -- bottom right to top left win - you get 3x your bet
            win = win + (betAmount * 3 * ResolveTypeMultiplier(slot0row2))
            table.insert(lines, {x = c0, y = r2, ex = c2, ey = r0})
        elseif IsFruit(slot0row2) and IsFruit(slot1row1) and IsFruit(slot2row0) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + betAmount
            table.insert(lines, {x = c0, y = r2, ex = c2, ey = r0})
        end
    end

    -- V and ^ matching
    -- ^ 2 in middle row
    if slot0row1 ~= ID_EMPTY and slot1row0 ~= ID_EMPTY and slot2row1 ~= ID_EMPTY then
        if slot0row1 == slot1row0 and slot0row1 == slot2row1 then
            -- 2x bet
            win = win + (betAmount * 1 * ResolveTypeMultiplier(slot0row1))
            table.insert(lines, {x = c0, y = r1, ex = c1, ey = r0})
            table.insert(lines, {x = c1, y = r0, ex = c2, ey = r1})
        elseif IsFruit(slot0row1) and IsFruit(slot1row0) and IsFruit(slot2row1) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + betAmount
            table.insert(lines, {x = c0, y = r1, ex = c1, ey = r0})
            table.insert(lines, {x = c1, y = r0, ex = c2, ey = r1})
        end
    end
    -- v 2 in top row
    if slot0row0 ~= ID_EMPTY and slot1row1 ~= ID_EMPTY and slot2row0 ~= ID_EMPTY then
        if slot0row0 == slot1row1 and slot0row0 == slot2row0 then
            -- 2x bet
            win = win + (betAmount * 1 * ResolveTypeMultiplier(slot0row0))
            table.insert(lines, {x = c0, y = r0, ex = c1, ey = r1})
            table.insert(lines, {x = c1, y = r1, ex = c2, ey = r0})
        elseif IsFruit(slot0row0) and IsFruit(slot1row1) and IsFruit(slot2row0) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + betAmount
            table.insert(lines, {x = c0, y = r0, ex = c1, ey = r1})
            table.insert(lines, {x = c1, y = r1, ex = c2, ey = r0})
        end
    end
    -- v 2 in middle row
    if slot0row1 ~= ID_EMPTY and slot1row2 ~= ID_EMPTY and slot2row1 ~= ID_EMPTY then
        if slot0row1 == slot1row2 and slot0row1 == slot2row1 then
            -- 2x bet
            win = win + (betAmount * 1 * ResolveTypeMultiplier(slot0row1))
            table.insert(lines, {x = c0, y = r1, ex = c1, ey = r2})
            table.insert(lines, {x = c1, y = r2, ex = c2, ey = r1})
        elseif IsFruit(slot0row1) and IsFruit(slot1row2) and IsFruit(slot2row1) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + betAmount
            table.insert(lines, {x = c0, y = r1, ex = c1, ey = r2})
            table.insert(lines, {x = c1, y = r2, ex = c2, ey = r1})
        end
    end
    -- ^ 2 in bottom row
    if slot0row2 ~= ID_EMPTY and slot1row1 ~= ID_EMPTY and slot2row2 ~= ID_EMPTY then
        if slot0row2 == slot1row1 and slot0row2 == slot2row2 then
            -- 2x bet
            win = win + (betAmount * 1 * ResolveTypeMultiplier(slot0row2))
            table.insert(lines, {x = c0, y = r2, ex = c1, ey = r1})
            table.insert(lines, {x = c1, y = r1, ex = c2, ey = r2})
        elseif IsFruit(slot0row2) and IsFruit(slot1row1) and IsFruit(slot2row2) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + betAmount
            table.insert(lines, {x = c0, y = r2, ex = c1, ey = r1})
            table.insert(lines, {x = c1, y = r1, ex = c2, ey = r2})
        end
    end


    term.setCursorPos(1, 2)
    term.setBackgroundColor(colors.orange)
    term.setTextColor(colors.black)
    if win == 0 then
        print("Better luck next time!")
    else
        print("You won " .. win .. " diamonds!")

        local remainingBalanceToPay = win - MoveBalance(bankStorage, balanceStorage, win)
        -- If there is any remaining balance to pay, the bank chest is empty and we need to print a playNote
        if remainingBalanceToPay > 0 then
            -- Print balance owed and save to our local storage
            ProcessBalanceOwed(gameId, remainingBalanceToPay, balanceName, printer, printerStorage, withdrawalStorage)
        end

        -- Draw the win lines
        for i=1,5 do
            speaker.playNote("xylophone", 1.0, 6)
            for _, line in ipairs(lines) do
                paintutils.drawLine(line.x, line.y, line.ex, line.ey, colors.red)
            end
            sleep(0.25)
            speaker.playNote("xylophone", 1.0, 12)
            for _, line in ipairs(lines) do
                paintutils.drawLine(line.x, line.y, line.ex, line.ey, colors.lime)
            end
            sleep(0.25)
        end
    end

    -- Draw balance and bet amount
    UpdateBalance()

    return true
end

while true do
    -- Check balance of the bank chest is above or equal to the threshold to play, break if not
    local bankBalance = GetBalance(bankStorage)
    if bankBalance < bankThreshold then
        EnterBankAdminScene(bankStorage, bankThreshold)
        speaker.playNote("guitar", 1.0, 4)
        sleep(0.4)
        speaker.playNote("guitar", 1.0, 1)
    else
        local play = EnterCreditsScene(depositStorage, balanceStorage, "Slots", betAmount)
        if play == false then
            -- Withdraw
            MoveBalance(balanceStorage, withdrawalStorage, GetBalance(balanceStorage))
            for i=1,3 do
                speaker.playNote("bell", 2.0, 12)
                sleep(0.2)
            end
        else
            -- Wait for input
            local playing = Play()
            while playing do
                -- Check balance of the bank chest is above or equal to the threshold to play, break if not
                bankBalance = GetBalance(bankStorage)
                if bankBalance < bankThreshold then
                    -- Withdraw automatically
                    MoveBalance(balanceStorage, withdrawalStorage, GetBalance(balanceStorage))
                    break
                end

                os.pullEvent("redstone")
                local exitSignal = redstone.getInput(WITHDRAW_REDSTONE_SIDE)
                if exitSignal == true then
                    -- When the player makes a withdrawal, move all from the balance chest to the withdrawal chest
                    MoveBalance(balanceStorage, withdrawalStorage, GetBalance(balanceStorage))
                    for i=1,3 do
                        speaker.playNote("bell", 2.0, 12)
                        sleep(0.2)
                    end
                    break
                else
                    local rollSlotsSignal = redstone.getInput(PLAY_REDSTONE_SIDE)
                    if rollSlotsSignal == true then
                        playing = Play() -- back to count diamond screen if out of balance
                    end
                end
            end
        end
    end
end