return {
    gameId = "SL-01",
    balanceType = "minecraft:diamond",
    balanceName = "diamonds",
    balanceImage = "diamond_image.nfp",
    betAmount = 5,
    bankThreshold = 50,

    -- Peripherals
    monitor = peripheral.wrap("monitor_0"),
    speaker = peripheral.wrap("speaker_0"),
    printer = peripheral.wrap("printer_0"),
    withdrawalStorage = peripheral.wrap("minecraft:barrel_0"),
    depositStorage = peripheral.wrap("minecraft:barrel_1"),
    balanceStorage = peripheral.wrap("minecraft:chest_0"),
    bankStorage = peripheral.wrap("minecraft:chest_1"),
    printerStorage = peripheral.wrap("minecraft:chest_4")
}