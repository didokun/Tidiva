import Foundation

let profile = HomeRhythm()
let day = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 12))!
profile.roomList = "Kitchen,Office,Entryway"
profile.floors = 2
profile.setFloor(.office, 2)
profile.workspace = "Office"
profile.priority = "Kitchen"
profile.work = "Hybrid"
profile.remoteDays = 1 << 2
profile.favorite = ""
precondition(profile.recommendation(on: day) == .pause)
profile.favorite = "guests"
precondition(profile.recommendation(on: day) == .guests)
func tasks(_ routine: Routine, _ history: [Reset] = []) -> [RoutineTask] {
    RoutineBuilder.tasks(routine, rhythm: profile, budget: 5, history: history, date: day)
}
let pause = tasks(.pause)
precondition(!pause.isEmpty && pause.allSatisfy { $0.room == .office })
precondition(pause.reduce(0) { $0 + $1.minutes } <= 5)
let first = pause[0]
let previous = Reset(first.title, room: first.room, minutes: first.minutes, scheduled: day)
precondition(tasks(.pause, [previous]).first?.existing === previous)
previous.completed = day
precondition(!tasks(.pause, [previous]).contains { $0.id == first.id })
previous.completed = nil
previous.sundayOnly = true
precondition(!tasks(.pause, [previous]).contains { $0.id == first.id })
precondition(tasks(.guests).first?.room == .entry)
precondition(tasks(.arrival).allSatisfy { $0.room == .kitchen })
print("Routine selection checks passed")

let firstBedroom = Room(name: "Bedroom", level: 1, custom: false)
let secondBedroom = Room(name: "Bedroom", level: 2, custom: false)
let music = Room(name: "Studio: musique, piano", level: 3, custom: true)
profile.floors = 3
profile.saveRooms([firstBedroom, secondBedroom, music])
precondition(profile.rooms == [firstBedroom, secondBedroom, music])
precondition(profile.rooms.map(profile.floor) == [1, 2, 3])
precondition(music.displayName == "Studio: musique, piano")
profile.workspace = secondBedroom.rawValue
let upstairs = tasks(.pause)
precondition(!upstairs.isEmpty && upstairs.allSatisfy { $0.room == secondBedroom })
let doneBelow = Reset(upstairs[0].title, room: firstBedroom, minutes: 2, scheduled: day)
doneBelow.completed = day
precondition(tasks(.pause, [doneBelow]).first?.id == upstairs[0].id)
profile.priority = music.rawValue
precondition(tasks(.arrival).first?.room == music)
print("Three-level layout and custom room checks passed")
