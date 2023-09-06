-- Fetch the latest version of each file for the slot game
fs.delete("game_slots.lua")
fs.delete("slot_cherry.nfp")
fs.delete("slot_grape.nfp")
fs.delete("slot_lemon.nfp")
fs.delete("slot_seven.nfp")
fs.delete("diamond_image.nfp")
-- don't delete config, only fetch if it doesn't exist yet

shell.run("wget", "https://raw.githubusercontent.com/CrispingChicken/CC-Casino/master/src/game/game_slots.lua")
shell.run("wget", "https://raw.githubusercontent.com/CrispingChicken/CC-Casino/master/src/game/diamond_image.nfp")
shell.run("wget", "https://raw.githubusercontent.com/CrispingChicken/CC-Casino/master/src/game/slot_cherry.nfp")
shell.run("wget", "https://raw.githubusercontent.com/CrispingChicken/CC-Casino/master/src/game/slot_grape.nfp")
shell.run("wget", "https://raw.githubusercontent.com/CrispingChicken/CC-Casino/master/src/game/slot_lemon.nfp")
shell.run("wget", "https://raw.githubusercontent.com/CrispingChicken/CC-Casino/master/src/game/slot_seven.nfp")

-- only fetch config if it doesn't exist yet
if fs.exists("config.lua") == false then
    shell.run("wget", "https://raw.githubusercontent.com/CrispingChicken/CC-Casino/master/src/game/config.lua")
end