import Foundation

enum SeedData {
    @MainActor
    static func makeStore(now: Date) -> DataStore {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)

        func at(_ daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = cal.date(byAdding: .day, value: -daysAgo, to: startOfToday)!
            return cal.date(byAdding: .minute, value: hour * 60 + minute, to: day)!
        }

        // Moment IDs (declared up front so tasks + people can reference them)
        let mMayaBook       = UUID()
        let mSamFreelance   = UUID()
        let mDental         = UUID()
        let mMayaTrueLaurel = UUID()
        let mMayaTartine    = UUID()
        let mSamMomBirthday = UUID()
        let mHike           = UUID()

        let moments: [Moment] = [

            // — 4 days ago: Maya book + bakery recs (drives the resurfaced card + carried-over task)
            Moment(
                id: mMayaBook,
                createdAt: at(4, 11, 12),
                source: .necklace,
                title: "Maya's book + bakery recs",
                rawTranscript: """
                Maya was telling me about this novel she just finished — \
                The Lighthouse Years by Eliza Voss, said it kind of wrecked her in a \
                good way. Oh and she also kept going on about that bakery in SF, \
                Tartine — said the morning bun is the best she's ever had. Want to \
                remember to pick up the book this week.
                """,
                polishedSummary: """
                Maya recommended The Lighthouse Years by Eliza Voss — said it \
                "wrecked her in a good way." Also raved about the morning bun at \
                Tartine in SF.
                """,
                tags: ["recommendation", "books", "food"]
            ),

            // — 3 days ago: Sam (sister) considering freelance
            Moment(
                id: mSamFreelance,
                createdAt: at(3, 18, 30),
                source: .necklace,
                title: "Sam: freelance question",
                rawTranscript: """
                Talked to Sam tonight. She's seriously thinking about leaving the \
                design firm and going freelance — sounded torn, excited about the \
                work but anxious about the income piece. Wants to actually talk it \
                through this weekend.
                """,
                polishedSummary: """
                Sam is considering leaving her design firm to freelance. Torn between \
                excitement about the work and anxiety about the income. Wants to talk \
                it through this weekend.
                """,
                tags: ["family"]
            ),

            // — Yesterday morning: dental reminder (carried-over task)
            Moment(
                id: mDental,
                createdAt: at(1, 9, 21),
                source: .phone,
                title: "Dental cleaning reminder",
                rawTranscript: """
                Dr. Patel's office called — I'm due for a cleaning, they said before \
                the end of June ideally. Need to actually book it instead of letting \
                this slide again.
                """,
                polishedSummary: """
                Dr. Patel's office said a cleaning is due before the end of June.
                """,
                tags: ["health", "errand"]
            ),

            // — Yesterday evening: Maya again (True Laurel)
            Moment(
                id: mMayaTrueLaurel,
                createdAt: at(1, 19, 43),
                source: .necklace,
                title: "Maya: True Laurel",
                rawTranscript: """
                Maya texted about this cocktail bar in Oakland — True Laurel? Said the \
                back patio is incredible right now. We should go together soon.
                """,
                polishedSummary: """
                Maya recommended True Laurel cocktail bar in Oakland — back patio is \
                "incredible right now." Wants to go together.
                """,
                tags: ["recommendation", "food"]
            ),

            // — Today, morning: Maya/Tartine thought
            Moment(
                id: mMayaTartine,
                createdAt: at(0, 8, 32),
                source: .necklace,
                title: "Coffee + Tartine thought",
                rawTranscript: """
                Drinking the worst coffee, thinking about Maya going on and on about \
                that Tartine morning bun. Honestly might be worth the drive into the \
                city next weekend.
                """,
                polishedSummary: """
                Considering a trip to Tartine in SF for the morning bun Maya \
                recommended — possibly next weekend.
                """,
                tags: ["food"]
            ),

            // — Today, mid-morning: Mom's birthday with Sam
            Moment(
                id: mSamMomBirthday,
                createdAt: at(0, 10, 15),
                source: .phone,
                title: "Mom's birthday brunch",
                rawTranscript: """
                Sam wants to do a brunch for Mom's birthday on Saturday June 14th. \
                Need to email her back today — confirm I'm in, ask if she wants me \
                to handle the reservation.
                """,
                polishedSummary: """
                Sam is planning Mom's birthday brunch for Saturday, June 14. Owes Sam \
                an email today to confirm and offer to handle the reservation.
                """,
                tags: ["family"]
            ),

            // — Today, afternoon: hike reflection (no tasks, no people — pure thought)
            Moment(
                id: mHike,
                createdAt: at(0, 14, 48),
                source: .necklace,
                title: "Wildcat Canyon hike",
                rawTranscript: """
                That trail off Wildcat Canyon was perfect this morning — totally \
                empty, found a new creek crossing. Bring proper water shoes next \
                time, the rocks were sharper than they looked.
                """,
                polishedSummary: """
                New trail off Wildcat Canyon felt empty and perfect. Note: bring water \
                shoes for the creek crossing next time.
                """,
                tags: ["outdoors"]
            ),
        ]

        // — People (provenance: which moments each person appears in)
        let people: [Person] = [
            Person(
                name: "Maya",
                facts: [
                    "Recommended The Lighthouse Years by Eliza Voss — said it \"wrecked her in a good way\"",
                    "Raves about the morning bun at Tartine (SF)",
                    "Mentioned True Laurel cocktail bar in Oakland — wants to go together",
                ],
                mentionedInMomentIDs: [mMayaBook, mMayaTrueLaurel, mMayaTartine]
            ),
            Person(
                name: "Sam",
                facts: [
                    "Considering leaving her design firm to freelance — torn between excitement and income anxiety",
                    "Planning Mom's birthday brunch for Saturday, June 14",
                ],
                mentionedInMomentIDs: [mSamFreelance, mSamMomBirthday]
            ),
            Person(
                name: "Dr. Patel",
                facts: [
                    "My dentist — office said a cleaning is due before the end of June",
                ],
                mentionedInMomentIDs: [mDental]
            ),
        ]

        // — Tasks (provenance: each task points back to its source moment)
        let endOfJune = cal.date(from: DateComponents(
            year: cal.component(.year, from: now),
            month: 6,
            day: 30,
            hour: 18
        ))

        let tasks: [TaskItem] = [
            TaskItem(
                text: "Pick up The Lighthouse Years from the library",
                status: .open,
                sourceMomentID: mMayaBook
            ),
            TaskItem(
                text: "Book dental cleaning with Dr. Patel",
                status: .open,
                dueAt: endOfJune,
                sourceMomentID: mDental
            ),
            TaskItem(
                text: "Try True Laurel cocktail bar in Oakland",
                status: .open,
                sourceMomentID: mMayaTrueLaurel
            ),
            TaskItem(
                text: "Email Sam back re: Mom's birthday brunch (June 14)",
                status: .open,
                sourceMomentID: mSamMomBirthday
            ),
        ]

        return DataStore(
            moments: moments.sorted { $0.createdAt > $1.createdAt },
            tasks: tasks,
            people: people
        )
    }
}
