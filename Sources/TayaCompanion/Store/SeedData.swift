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
        let mJournalSunday  = UUID()
        let mJournalLate    = UUID()
        let mJournalRain    = UUID()
        let mJournalBday    = UUID()

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
                tags: ["health", "errand"],
                place: "Oakland"
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

            // — Today, early morning: reflection entry
            Moment(
                id: mJournalSunday,
                createdAt: at(0, 7, 12),
                source: .phone,
                title: "Slow Sunday morning",
                rawTranscript: """
                Woke up before the alarm and the apartment was so quiet it felt like \
                a held breath. Made coffee the slow way, sat by the window, watched \
                the fog do its thing over the hills. I don't remember the last time \
                I let a morning just be a morning without reaching for the phone.
                """,
                polishedSummary: """
                A rare quiet morning — coffee, the window, the fog. First morning in \
                a long time without reaching for the phone.
                """,
                tags: ["reflection"]
            ),

            // — Yesterday evening: reflection entry
            Moment(
                id: mJournalLate,
                createdAt: at(1, 22, 41),
                source: .phone,
                title: "Late, can't sleep",
                rawTranscript: """
                Lying in bed turning over the conversation with Sam. She sounded \
                lighter than I expected — not resolved, but lighter, like just \
                saying it out loud was half the work. I keep wanting to fix it for \
                her and that's not what she needs from me right now.
                """,
                polishedSummary: """
                Replaying the call with Sam — she sounded lighter than expected. \
                Reminder: she wants to be heard, not fixed.
                """,
                tags: ["family", "reflection"]
            ),

            // — 3 days ago: reflection entry
            Moment(
                id: mJournalRain,
                createdAt: at(3, 8, 5),
                source: .phone,
                title: "Rain and the long walk",
                rawTranscript: """
                Walked the long loop in the rain instead of skipping it. Got back \
                soaked through and weirdly proud of myself, like I'd negotiated \
                something with the weather. Reminded me of those winter mornings \
                in Portland when nothing felt as honest as just being outside.
                """,
                polishedSummary: """
                Walked the long loop in the rain anyway. Came back soaked and \
                quietly proud — felt like Portland winters.
                """,
                tags: ["outdoors", "reflection"]
            ),

            // — 5 days ago: reflection entry
            Moment(
                id: mJournalBday,
                createdAt: at(5, 20, 17),
                source: .phone,
                title: "Thinking about Mom's birthday",
                rawTranscript: """
                Trying to think of something for Mom that isn't another scarf. She \
                keeps saying she doesn't want anything but she always lights up at \
                the small specific things — the photo Sam printed last year, the \
                playlist I made the summer Dad was sick. The gift is the noticing, \
                not the thing.
                """,
                polishedSummary: """
                Mom's birthday gift — the noticing matters more than the object. \
                Think small, specific, made-by-hand.
                """,
                tags: ["family", "reflection"]
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
                sourceMomentIDs: [mMayaBook, mMayaTrueLaurel, mMayaTartine]
            ),
            Person(
                name: "Sam",
                facts: [
                    "Considering leaving her design firm to freelance — torn between excitement and income anxiety",
                    "Planning Mom's birthday brunch for Saturday, June 14",
                ],
                sourceMomentIDs: [mSamFreelance, mSamMomBirthday]
            ),
            Person(
                name: "Dr. Patel",
                facts: [
                    "My dentist — office said a cleaning is due before the end of June",
                ],
                sourceMomentIDs: [mDental]
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
                sourceMomentIDs: [mMayaBook]
            ),
            TaskItem(
                text: "Book dental cleaning with Dr. Patel",
                status: .open,
                dueAt: endOfJune,
                sourceMomentIDs: [mDental]
            ),
            TaskItem(
                text: "Try True Laurel cocktail bar in Oakland",
                status: .open,
                sourceMomentIDs: [mMayaTrueLaurel]
            ),
            TaskItem(
                text: "Email Sam back re: Mom's birthday brunch (June 14)",
                status: .open,
                sourceMomentIDs: [mSamMomBirthday]
            ),
        ]

        // — Seeded chat history. Times are loosely positioned across the
        // last few days so the list view has visible recency variation.
        let chats: [Chat] = [
            Chat(
                title: "Maya's recommendations",
                messages: [
                    ChatMessage(
                        role: .user,
                        text: "What did Maya recommend?",
                        createdAt: at(0, 10, 28)
                    ),
                    ChatMessage(
                        role: .taya,
                        text: """
                        Maya gave you three recommendations in the last few days:

                        • The Lighthouse Years by Eliza Voss — she said it "wrecked her in a good way"
                        • Tartine in SF — raved about the morning bun
                        • True Laurel in Oakland — wants to go together
                        """,
                        createdAt: at(0, 10, 28)
                    ),
                    ChatMessage(
                        role: .user,
                        text: "Anything I haven't acted on yet?",
                        createdAt: at(0, 10, 30)
                    ),
                    ChatMessage(
                        role: .taya,
                        text: """
                        Two open tasks tied to Maya's recs:

                        • Pick up The Lighthouse Years (from Wed)
                        • Try True Laurel cocktail bar (from yesterday)

                        The Tartine idea is captured but no task yet.
                        """,
                        createdAt: at(0, 10, 30)
                    ),
                ]
            ),
            Chat(
                title: "Wildcat Canyon trail",
                messages: [
                    ChatMessage(
                        role: .user,
                        text: "Where did I go on the hike?",
                        createdAt: at(1, 16, 12)
                    ),
                    ChatMessage(
                        role: .taya,
                        text: """
                        Wildcat Canyon — you found a new trailhead and noted the creek crossing is sharper than it looked. You wanted to bring water shoes next time.
                        """,
                        createdAt: at(1, 16, 12)
                    ),
                ]
            ),
            Chat(
                title: "Sam: freelance question",
                messages: [
                    ChatMessage(
                        role: .user,
                        text: "What did Sam say about freelancing?",
                        createdAt: at(2, 20, 5)
                    ),
                    ChatMessage(
                        role: .taya,
                        text: """
                        Sam is considering leaving the design firm to freelance. She's torn — excited about the work but anxious about income. She wants to talk it through this weekend.
                        """,
                        createdAt: at(2, 20, 5)
                    ),
                ]
            ),
            Chat(
                title: "Quick suggestion",
                messages: [
                    ChatMessage(
                        role: .user,
                        text: "Suggest something good for tonight",
                        createdAt: at(4, 18, 41)
                    ),
                    ChatMessage(
                        role: .taya,
                        text: """
                        Based on what you've been thinking about: try True Laurel — Maya's been talking it up, and the open task is sitting there waiting.
                        """,
                        createdAt: at(4, 18, 41)
                    ),
                ]
            ),
        ]

        // — Proactive proposals Taya has done work on (the "For you" lens).
        // Two different shapes so the pattern reads as general, not just
        // restaurants: one reservation-style, one set of ideas.
        let suggestions: [Suggestion] = [
            Suggestion(
                lead: "You mentioned wanting a date spot in the city for Friday night. I found a few with tables open around 7:30 that I think you'd like.",
                options: [
                    SuggestionOption(title: "True Laurel", subtitle: "Cocktail bar · Mission", detail: "Table for 2 · Fri 7:30 PM", systemImage: "wineglass", url: URL(string: "https://www.opentable.com/s?term=True%20Laurel")),
                    SuggestionOption(title: "Lazy Bear", subtitle: "New American · Mission", detail: "2 seats · Fri 8:00 PM", systemImage: "fork.knife", url: URL(string: "https://www.opentable.com/s?term=Lazy%20Bear")),
                    SuggestionOption(title: "Tartine Manufactory", subtitle: "Café · Mission", detail: "Table for 2 · Fri 7:15 PM", systemImage: "cup.and.saucer", url: URL(string: "https://www.opentable.com/s?term=Tartine%20Manufactory")),
                ]
            ),
            Suggestion(
                lead: "Mom's birthday is coming up on June 14. You said it best — the gift is the noticing — so here are a few small, specific ideas.",
                sourceMomentID: mJournalBday,
                options: [
                    SuggestionOption(title: "A printed photo book", subtitle: "From this year together", detail: "~$45 · arrives in 3 days", systemImage: "book.closed"),
                    SuggestionOption(title: "Rosemary garden kit", subtitle: "She asked about your cuttings", detail: "~$30 · local nursery", systemImage: "leaf"),
                    SuggestionOption(title: "A handwritten recipe box", subtitle: "The dishes she taught you", detail: "An afternoon to make", systemImage: "square.and.pencil"),
                ]
            ),
        ]

        return DataStore(
            moments: moments.sorted { $0.createdAt > $1.createdAt },
            tasks: tasks,
            people: people,
            chats: chats,
            suggestions: suggestions
        )
    }
}
