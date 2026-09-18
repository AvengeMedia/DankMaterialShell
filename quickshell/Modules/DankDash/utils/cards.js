function stored() {
    return DashRegistry.placed.slice()
}

function addCard(id, w, h) {
    const cards = stored()
    cards.push({
        "id": id,
        "w": w,
        "h": h
    })
    SettingsData.set("dashCards", cards)
}

function removeCard(index) {
    const cards = stored()
    if (index < 0 || index >= cards.length)
        return
    cards.splice(index, 1)
    SettingsData.set("dashCards", cards)
}

function setSize(index, w, h) {
    const cards = stored()
    if (index < 0 || index >= cards.length)
        return
    const card = cards[index]
    if (card.w === w && card.h === h)
        return
    cards[index] = {
        "id": card.id,
        "w": w,
        "h": h
    }
    SettingsData.set("dashCards", cards)
}

function reorder(newList) {
    SettingsData.set("dashCards", newList)
}

function clearAll() {
    SettingsData.set("dashCards", [])
}

function moveCard(index, delta) {
    const cards = stored()
    const target = index + delta
    if (index < 0 || index >= cards.length || target < 0 || target >= cards.length)
        return
    const card = cards.splice(index, 1)[0]
    cards.splice(target, 0, card)
    SettingsData.set("dashCards", cards)
}

function resetToDefault() {
    SettingsData.resetDashCards()
}
