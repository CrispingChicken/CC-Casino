-- Simulate the slot rolls 100,000 times to see when the player goes broke with 10,000 balance
local betAmount = 5
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

function IsFruit(slotType)
    if slotType == ID_CHERRY or slotType == ID_LEMON or slotType == ID_GRAPE then
        return true
    end
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
local balance = 100
--local balen = 37745
local MAX_RUNS = 10000
local numRuns = 0
local numWins = 0
local maxBalanceInRun = balance

-- return true if balance remains, else false
function Play()
    -- Check balance
    if balance < betAmount then
        print("Not enough balance")
    end

    balance = balance - betAmount

    -- Spin all 3 slots
    local numSpins = math.random(10, 20)
    for i = 1,numSpins do
        slot0Index = slot0Index + 1
        slot1Index = slot1Index + 1
        slot2Index = slot2Index + 1
    end

    -- Spin remaining 2 slots
    numSpins = math.random(5, 15)
    for i = 1,numSpins do
        slot1Index = slot1Index + 1
        slot2Index = slot2Index + 1
    end

    -- Spin last slot
    numSpins = math.random(5, 15)
    for i = 1,numSpins do
        slot2Index = slot2Index + 1
    end

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

    -- Column/row centers
    local win = 0

    -- Row matching
    -- Row 0
    if slot0row0 ~= ID_EMPTY and slot1row0 ~= ID_EMPTY and slot2row0 ~= ID_EMPTY then
        if slot0row0 == slot1row0 and slot0row0 == slot2row0 then
            -- top row win - you get 2x your bet * slot multiplier
            win = win + (betAmount * 2 * ResolveTypeMultiplier(slot0row0))
        elseif IsFruit(slot0row0) and IsFruit(slot1row0) and IsFruit(slot2row0) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + (betAmount * 1.5)
        end
    end
    -- Row 1
    if slot0row1 ~= ID_EMPTY and slot1row1 ~= ID_EMPTY and slot2row1 ~= ID_EMPTY then
        if slot0row1 == slot1row1 and slot0row1 == slot2row1 then
            -- middle row win - you get 5x your bet
            win = win + (betAmount * 5  * ResolveTypeMultiplier(slot0row1))
        elseif IsFruit(slot0row1) and IsFruit(slot1row1) and IsFruit(slot2row1) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + (betAmount * 1.5)
        end
    end
    -- Row 2
    if slot0row2 ~= ID_EMPTY and slot1row2 ~= ID_EMPTY and slot2row2 ~= ID_EMPTY then
        if slot0row2 == slot1row2 and slot0row2 == slot2row2 then
            -- bottom row win - you get 2x your bet
            win = win + (betAmount * 2 * ResolveTypeMultiplier(slot0row2))
        elseif IsFruit(slot0row2) and IsFruit(slot1row2) and IsFruit(slot2row2) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + (betAmount * 1.5)
        end
    end

    -- Diagonal matching
    -- Top left to bottom right
    if slot0row0 ~= ID_EMPTY and slot1row1 ~= ID_EMPTY and slot2row2 ~= ID_EMPTY then
        if slot0row0 == slot1row1 and slot0row0 == slot2row2 then
            -- top left to bottom right win - you get 3x your bet
            win = win + (betAmount * 3 * ResolveTypeMultiplier(slot0row0))
        elseif IsFruit(slot0row0) and IsFruit(slot1row1) and IsFruit(slot2row2) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + (betAmount * 1.5)
        end
    end
    -- Bottom left to top right
    if slot0row2 ~= ID_EMPTY and slot1row1 ~= ID_EMPTY and slot0row2 ~= ID_EMPTY then
        if slot0row2 == slot1row1 and slot0row2 == slot2row0 then
            -- bottom right to top left win - you get 3x your bet
            win = win + (betAmount * 3 * ResolveTypeMultiplier(slot0row2))
        elseif IsFruit(slot0row2) and IsFruit(slot1row1) and IsFruit(slot2row0) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + (betAmount * 1.5)
        end
    end


    -- V and ^ matching
    -- ^ 2 in middle row
    if slot0row1 ~= ID_EMPTY and slot1row0 ~= ID_EMPTY and slot2row1 ~= ID_EMPTY then
        if slot0row1 == slot1row0 and slot0row1 == slot2row1 then
            -- 2x bet
            win = win + (betAmount * ResolveTypeMultiplier(slot0row1))
        elseif IsFruit(slot0row1) and IsFruit(slot1row0) and IsFruit(slot2row1) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + betAmount
        end
    end
    -- v 2 in top row
    if slot0row0 ~= ID_EMPTY and slot1row1 ~= ID_EMPTY and slot2row0 ~= ID_EMPTY then
        if slot0row0 == slot1row1 and slot0row0 == slot2row0 then
            -- 2x bet
            win = win + (betAmount* ResolveTypeMultiplier(slot0row0))
        elseif IsFruit(slot0row0) and IsFruit(slot1row1) and IsFruit(slot2row0) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + betAmount
        end
    end
    -- v 2 in middle row
    if slot0row1 ~= ID_EMPTY and slot1row2 ~= ID_EMPTY and slot2row1 ~= ID_EMPTY then
        if slot0row1 == slot1row2 and slot0row1 == slot2row1 then
            -- 2x bet
            win = win + (betAmount * ResolveTypeMultiplier(slot0row1))
        elseif IsFruit(slot0row1) and IsFruit(slot1row2) and IsFruit(slot2row1) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + betAmount
        end
    end
    -- ^ 2 in bottom row
    if slot0row2 ~= ID_EMPTY and slot1row1 ~= ID_EMPTY and slot2row2 ~= ID_EMPTY then
        if slot0row2 == slot1row1 and slot0row2 == slot2row2 then
            -- 2x bet
            win = win + (betAmount * ResolveTypeMultiplier(slot0row2))
        elseif IsFruit(slot0row2) and IsFruit(slot1row1) and IsFruit(slot2row2) then
            -- If they don't match but they are all fruit, get your bet back
            win = win + betAmount
        end
    end

	if win > 0 then
		numWins = numWins + 1
	end

	if win >= 100 then
	    print("Win: " .. win)
	end

	balance = balance + win
	if balance > maxBalanceInRun then
		maxBalanceInRun = balance
	end
    return true
end


math.randomseed(os.time())

-- Wait for input
while balance > 0 and numRuns < MAX_RUNS and Play() do
	numRuns = numRuns + 1
end

print(numWins .. "/" .. numRuns .. " wins, end balance: " .. balance .. " peak balance: " .. maxBalanceInRun)
