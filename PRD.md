Charades Party Game (Heads-Up Style) – Product
Requirements Document
Introduction
Heads Up! by Warner Bros. (popularized by Ellen DeGeneres) is one of the most engaging mobile party
games, having gained massive popularity across iOS and Android 1
. It’s essentially a digital take on
charades, where a player holds the phone to their forehead displaying a word, and friends shout clues to
help guess it before time runs out 2
. Inspired by this “guess the word on your head” gameplay, our app
will deliver a fun, intuitive, and highly engaging charades experience that meets or exceeds industry
standards. The goal is to combine user-friendly design, social gameplay, and effective monetization so
that users of all ages keep coming back for more. This PRD outlines the complete feature set, user
experience (UX/UI) design guidelines, monetization strategy, and detailed screen-by-screen requirements
for our charades party game app.
Objectives and Goals
•
•
•
•
•
Highly Engaging Gameplay: Create a fun and hilarious party game that encourages group play
and keeps users entertained for hours, similar to the sensation that Heads Up! became 2
. The app
should facilitate lively in-person or remote play sessions, making users want to play again and again.
Exceptional User Experience: Deliver an intuitive and polished UI with colorful graphics and
smooth animations so that even new users (including kids) can instantly understand and enjoy the
game 3 4
. User flows must be simple (minimal taps to start a game) and the design should meet
modern industry standards for mobile apps.
Broad Audience Appeal: Cater to a wide audience – families, kids, teenagers, adults, and casual
party-goers. The content will be accessible to all ages and skill levels, with options to adjust
difficulty or select kid-friendly categories 3
. Localization (multi-language support) will be provided
to reach a global user base (the official Heads Up supports 74 languages 5
).
Monetization & Revenue: Implement a sustainable monetization strategy that includes Google
AdMob ads and optional in-app purchases, without compromising the user experience. The app will
be free to download, generating revenue via ad placements and offering premium upgrades (e.g.
remove ads or buy extra content) 6
. Ads must be integrated thoughtfully so they do not disrupt
gameplay (addressing common user complaints about intrusive ads 7
).
Retention & Virality: Encourage users to stay engaged through features like push notifications (for
new decks or challenges), social sharing of game moments, and fresh content updates. The app
should foster word-of-mouth growth by making it easy and rewarding for users to share their
experience on social media (e.g. sharing funny gameplay videos 8
). Regular content additions (new
9
decks, themes, events) will keep the game feeling new and exciting over time .
1
Target Audience and Platform
Target Users: The app targets groups of friends or family looking for a quick, fun party game. This
includes children (with parental guidance for content), teens, and adults. A “Family/Kids Mode” will ensure
younger players only see age-appropriate content, addressing concerns about inappropriate references in
some decks 10
. The game’s inclusive design (multiple difficulty levels and categories) will allow everyone
from casual players to trivia enthusiasts to enjoy the experience.
Platforms: The product will be developed for mobile devices on both Android and iOS (supporting
smartphones and tablets). Cross-platform consistency is important so that the experience feels the same on
all devices. The app will work offline for in-person play, with optional online features requiring internet. We
will follow design guidelines for both Android (Material Design) and iOS (Human Interface Guidelines) to
meet user expectations on each platform, while using a unified playful theme across both.
Competitive Landscape: Several charades and “guess the word” apps exist (e.g. the official Heads Up!,
“Charades!” etc.), each attracting large user bases. To stand out, our app will combine the best practices of
industry-leading apps with unique touches in content and design. Key differentiators will be a superior
user interface, a rich variety of free content (to avoid feeling “short on free word sets” as some competitors
do 11
), and a balanced ad strategy that doesn’t frustrate players. Our aim is to become the go-to party
game app by offering both quality and quantity in terms of decks and features.
Key Features and Requirements
Core Gameplay Mechanics
•
•
•
•
Forehead Charades Game Loop: The fundamental gameplay mirrors classic charades and Heads
Up: one player holds the device to their forehead, and a word (or phrase) is displayed for others to
see. The app uses the device’s accelerometer for gesture controls – tilting the device down indicates
a correct guess, and tilting up passes/skips the word 12
. These gestures trigger the next card and
are accompanied by fun auditory/visual feedback (e.g. a “Ding!” sound and green highlight for
correct 12
). A countdown timer (e.g. 60 seconds) is shown on screen, during which the guesser
tries to get as many words right as possible.
Tilt Detection & Alternatives: The app must accurately detect tilt gestures to avoid frustration. We
will fine-tune the sensitivity and provide an on-screen “Pass”/“Correct” button as a backup for users
who may have difficulty with tilting (ensuring accessibility for those with limited mobility or if using a
device without reliable sensors). The tilt control adds an immersive, physical element to gameplay
13
, so it should be emphasized, but the UI will also subtly remind the user of the option to tap if
needed (perhaps via an icon).
Scoring and Rounds: Each correct answer within the time limit counts as one point. At time’s up, the
round ends and the score (number of words guessed correctly) is displayed. There is no “fail state” –
the focus is on having fun and possibly beating your own or friends’ high score. If playing in teams
(see Multiplayer section), the score contributes to the team’s total. The game should maintain a
history of words that were passed or missed to show later (so players can laugh about the ones
they didn’t get). This history can be displayed on the results screen for fun and learning.
Content Cards (Words/Phrases): Cards can contain words or short phrases that players have to
act out or give clues for. In some categories, the clues might involve specific types of acting or
sounds – for example, in a “Act It Out” deck, the word might be an action the clue-giver must mime,
2
while in a “Music” deck it could be a song the clue-giver must hum 14
. Most cards will be text-
based (since that’s standard for adult players), but we will also support image-based cards for
certain categories or for young kids (e.g. a picture of an animal that kids have to identify, making the
game accessible to pre-readers). The app’s content management system should allow easily adding
new words or images to decks. All content must be vetted for appropriateness given the target
audience range (no explicit profanity, etc., unless in an adults-only deck that is clearly labeled).
Content and Categories
•
•
•
Diverse Deck Categories: The app will launch with a wide variety of card decks to appeal to
different interests. For example: Pop Culture, Movies, Celebrities, Animals, Literature, Music,
Accents & Impressions, Sports, Science, Kids (easy), etc. (mirroring many of the themes that made
Heads Up popular 15
). We plan to include at least 40+ decks from the start, ensuring the fun “never
has to stop” due to lack of content 16 17
. Each deck will have an identifying icon and a fun name.
Some decks may be licensed or niche (e.g. “Harry Potter Trivia” or “Marvel Heroes”) – these can be
premium content (see Monetization).
Custom Deck Creation: To boost engagement, users will have the option to create their own
custom decks. This feature lets users input a list of words/phrases (e.g. inside jokes, local language
words, educational vocab for classroom use, etc.). The app should provide a simple interface to add
custom cards, name the deck, and optionally share it with friends (possibly via a code or link). This
was a popular feature in Heads Up! (“create a category all your own” 18
), as it adds endless
replayability. Custom decks can be kept private or shared on a community library if we implement
one in the future (not in initial scope, but planned).
Content Updates and Seasonal Packs: To keep users returning, we will regularly add new cards
and even new decks, especially themed around seasons or current events. For example, a “Holiday
Charades” pack around December, or a “Women’s History Month” deck in March (just as the official
app did) 9
. These updates can be highlighted on the home screen and delivered via push
notifications. Limited-time decks can create urgency to play (“Available this week only!”) and if
popular, become permanent. Our content team will gather user feedback on deck ideas and track
which decks are most played to inform future additions.
Multiplayer and Social Play
•
•
Local Multiplayer (Teams Mode): The primary mode is in-person group play. We will support a
Teams Mode where players can split into two (or more) teams and take turns. The app will allow the
user to select team play at the start: if enabled, it will alternate between teams each round and keep
a running score for each team. A simple scoreboard view can display team scores after each round
and declare a winner after a set number of rounds. This formalizes the charades party experience
and keeps everyone competitive and engaged. (Users can also choose to play casually without
formal teams, which is essentially the default.)
Online Multiplayer (Remote play): To adapt to an era of remote socializing (and to broaden usage
beyond physical gatherings), the app will include an Online Play option. This allows friends in
different locations to play together. One possible implementation is a video chat integration or a
game lobby: for example, one player hosts a game and invites others via a code or link. The host’s
phone will display the word, and remote players can see it on their own screen or get a clue-giver
interface. We may leverage a simple real-time server for this mode – at minimum, we show the word
to everyone except the guesser (who maybe uses front-camera feed to show themselves to others).
For simplicity, initially the online mode might require players to use a separate video call (e.g. Zoom
3
•
•
or built-in video) while the app syncs the word and timer for all. This is an advanced feature, so it will
be clearly indicated as “Beta”. However, supporting play with friends or even random players
online would differentiate us and appeal to those who can’t meet in person 19
. Real-time
synchronization and voice chat are technical challenges but achievable with services like Firebase or
WebRTC.
Social Sharing Features: The game experience naturally leads to hilarious moments. Our app will
capitalize on this by making it easy to share those moments. If the user permits, the app will record
video via the front camera during gameplay (recording the guesser and the clue-givers’ reactions).
After a round, the user can review this video and share it to social media with one tap 8
. Even if
they don’t record video, we will provide a shareable summary card of the round (e.g. “I guessed 7
out of 10 words in 60 seconds on [AppName]!” with our logo) that can be posted to Facebook,
Twitter, Instagram, etc. There will also be a “Share this app” button or referral link on the home or
results screen to encourage inviting friends. Word-of-mouth and social media virality are crucial for
growing the user base.
Push Notifications & Challenges: The app will send notifications to re-engage users, but in a fun,
non-spammy way 20
. Examples: “New Deck Added: 2000s Hits! Update your app to play.” or “Can
you guess 10 animals in 60 seconds? Come back and try our new Animals deck!” We can also
implement periodic challenges or events – for instance, a weekend challenge where all players try
to achieve a certain score in a particular deck, with a leaderboard. These notifications will be
configurable (users can opt out or set frequency).
Personalization and Settings
•
•
•
•
Adjustable Round Parameters: Users can configure certain aspects of the game to match their
preferences. For example, number of cards per round (or the round timer length) can be adjusted –
e.g. 10 cards (around 60 seconds) by default, but allow anywhere from, say, 5 to 25 cards for a
shorter or longer game 21
. This flexibility accommodates both quick play sessions and longer game
nights.
Themes and UI Customization: The app will offer a few color themes or backgrounds so users
can personalize the look. For instance, a dark mode for low-light party environments, or the ability to
change the background color of the game screen to any color desired 22
. This not only improves
accessibility (some might prefer high contrast themes) but also gives a sense of ownership. We
might include fun background images or patterns corresponding to certain decks (e.g. a space-
themed background when playing a Sci-Fi deck). All theme choices will maintain clarity of the word
display.
Sound and Haptics: Sound effects (countdown tick, correct answer ding, times-up alarm, etc.) and
optional haptic feedback will make the game more immersive. In settings, users can toggle sound
effects and vibrate on/off. By default, we use upbeat, positive sounds to keep the energy high.
Background music will likely be minimal to avoid interference with players talking, but maybe a
lobby/background tune in menus for atmosphere.
Language Selection: If the app supports multiple languages (for both the UI and the content decks),
users can select their preferred language in the settings (or on first launch). We may auto-detect
device language but allow manual override via a Language Selection screen. This ensures that
players can enjoy decks in their native language and that our UI text is understandable globally.
Multi-language support is a key industry feature to attract a worldwide audience 5
. For example,
the clone app “Charades!” offers languages like English, Arabic, French, Spanish, etc., accessible via a
language menu (see image below).
4
Example: Offering multiple language options expands the app’s reach (the clone app above lets users choose their
language upfront). Our app will localize content and UI text into major languages to be user-friendly globally.
•
Profile and Stats: While not required to play, we can provide an optional user profile (especially if
accounts are enabled). The profile could show cumulative stats like total games played, total words
guessed, highest score in a single round, favorite category, and earned badges/achievements. Fun
achievements could be implemented to reward engagement (e.g. “Sharades Superstar – 1000 total
guesses!”, “Streak Master – 10 perfect rounds in a row”). These give users long-term goals and
bragging rights, enhancing retention. Profiles would be kept locally or in cloud (if user logs in with an
account).
•
Accounts & Cloud Sync (Optional): For phase 1, we may allow playing without any login (to reduce
friction). However, offering sign-in via Google, Apple, or Facebook can enable features like cloud sync
of custom decks and stats, and global leaderboards for any competitive modes. If accounts are used,
we must include standard options like password reset, and perhaps a nickname/avatar selection.
This is an optional feature that can be added if we see the need for a persistent user identity (for
example, to facilitate friend invites or saving shared decks).
Monetization Strategy
Our monetization approach combines advertising and in-app purchases in a way that maximizes revenue
while maintaining a great user experience. Below are the monetization features:
•
•
•
Google AdMob Ads: The app will integrate AdMob to serve ads. We will use a mix of ad formats:
small banner ads, interstitial ads, and rewarded video ads. Banner ads will appear at natural pause
points (for example, on the home screen or category selection screen, but not during active
gameplay) to avoid disrupting the fun. These banners provide continuous but low-impact revenue.
Interstitial ads (full-screen ads) will be used sparingly – for instance, after every 2 or 3 rounds, an
interstitial could show during the results screen or when returning to the main menu. We will be
careful not to show interstitials too frequently, heeding user feedback that too many ads in such
games can be annoying 7
. The timing will be such that they feel like a natural break (e.g., after a
game is finished, as a “break” before starting the next game, similar to best practices 23
).
Rewarded Ads for Unlockables: We plan to leverage rewarded video ads to enhance engagement
and provide value to non-paying users. For example, certain premium decks or content can be
unlocked for one round by watching a 30-second ad (instead of paying). Users could also earn a hint
or extra 30 seconds of time as a reward for watching an ad (though hints aren’t typically used in
charades, extra time could be). This strategy gives players a choice and a sense of getting a benefit,
which increases their satisfaction while still generating revenue 24
. Implementing rewarded ads in
exchange for premium content or extra gameplay is known to increase user retention and
25 26
satisfaction when done right .
In-App Purchases (IAP): Alongside ads, we will offer optional purchases. One major IAP will be a
“Remove Ads” one-time purchase or a premium upgrade. Paying users would enjoy an ad-free
experience (no banner/interstitials) and possibly some bonus decks. Additionally, we can sell
premium deck packs – for example, a bundle of licensed content or special categories (trivia about
popular movies, exclusive content packs). The original Heads Up makes a lot of revenue through
such IAP deck purchases 27
, so it’s a proven strategy. We may also consider a subscription model
5
•
•
(monthly VIP pass) which grants access to all premium decks and features plus no-ads 28
. This
subscription could be marketed as the ultimate party pack for enthusiasts.
Ad Placement and UX Considerations: All ads will be placed in a way that does not hinder
gameplay flow. No ads will display in the middle of a round or while the user is actively trying to use
the interface. Banner ads will be confined to lower portions of non-crucial screens (and not on small
sub-screens where space is tight). Interstitials will never be shown without the user expecting a
transition (so never surprise the user mid-action). We will follow Google’s guidelines for good ad
placement to maintain a quality user experience 29
. Also, a consent prompt (for GDPR, etc.) will be
included on first launch due to personalized ads; we’ll integrate a consent SDK if needed to comply
with privacy regulations (as required by AdMob’s policies in 2024 and beyond 30 31
).
Analytics and Optimization: We will track metrics like ad impressions, click-through rates, and
purchase conversion, using tools (Firebase Analytics, etc.) to optimize our monetization strategy. If
data shows certain ad formats are hurting retention, we will adjust frequency or placement. Our aim
is a balanced monetization: enough revenue to sustain development while keeping the game’s
reviews positive and users happy to stick around (a win-win for users and business 32
).
User Experience and UI Design
Our app’s UX/UI design will be guided by the principle that a well-designed interface boosts player
retention and enjoyment 4
. The style will be bright, friendly, and modern, evoking a party
atmosphere. Key design considerations include:
•
•
•
•
•
Intuitive Navigation: The app should require minimal instructions – users can understand how to
play at a glance. We will include a brief onboarding (see Screens below) but also make the core loop
discoverable (for example, an icon on the gameplay screen showing a downward arrow for correct
and upward arrow for pass as a quick reminder). All major functions (Play, Categories, Settings) will
be accessible from the home screen in one or two taps. Consistent icons and labels (using familiar
symbols like a gear for settings, trophy for achievements, etc.) will be used throughout.
Visual Appeal: We will use vibrant colors and playful graphics to make the app inviting. Each
category deck might have its own color theme or illustration (e.g., an animal icon for the Animals
deck). Animations will be used to give feedback (e.g., card flips, confetti on high score, etc.) creating
a polished feel. The overall aesthetic will be comparable to other hit casual games – friendly for kids
but stylish enough for adults. Typography will be bold and easy to read from a distance (since the
phone is held at arm’s length on someone’s forehead). We’ll ensure text (the word to guess) is large,
high-contrast, and in an easy-to-read font.
Smooth Performance: The interface must be responsive and smooth. Screen transitions (navigating
from menu to game, etc.) should be quick, with maybe a fun card-flip animation between rounds. We
target 60 FPS animations to make the game feel fluid. The app size will be kept reasonable by
optimizing assets, given that too large apps can deter some users.
Accessibility: We will support accessibility features such as VoiceOver/TalkBack for visually impaired
users (they might play as clue-givers), though the game inherently is visual. We will also include a
color-blind friendly mode if needed (ensuring any color-coding isn’t the sole means of conveying
information). Additionally, providing content in multiple languages is a big part of accessibility and
inclusiveness.
Feedback and Delight: Using sound effects, vibrations, and animations in response to user actions
(like tilting or tapping) will provide immediate feedback. For instance, when a correct answer is
registered, the whole screen might flash green and a pleasant ding plays – these small delights make
6
the experience satisfying. When time runs out, an animated scoreboard can slide into view. Such
touches make the app feel high-quality and engaging. The design will be tested with users to ensure
it’s fun and not confusing.
Importantly, our design approach will incorporate industry best practices from successful apps. For
example, onboarding tutorials will not send users to external videos (a flaw noted in a competitor review)
but instead use in-app guidance 33
. Overall, the app’s look and feel should convey “polish” and
professionalism on par with top-charting mobile games, while radiating the fun, party vibe that invites
people to play together.
Example: A user-friendly home screen from a charades app. Big, clear buttons (Play, Settings, How to Play) and a
fun illustration make it immediately obvious how to get started. Our app’s main menu will use a similarly intuitive
layout.
Application Screens and Content
This section details each screen in the mobile app and the elements and features it should contain. Each
screen description also touches on the intended user interaction and UI considerations for that screen.
1. Splash Screen
•
•
•
•
Description: A brief splash screen shown when the app launches. Typically displays the app’s logo
and maybe a tagline (“The Ultimate Charades Game!”) on a vibrant background. This screen is mainly
for branding.
Contents: App logo graphic and name, possibly an eye-catching animation (like cards sliding in). If
any loading is required on startup (initializing decks, etc.), a subtle progress indicator can be shown,
but ideally the splash transitions quickly to the next screen.
User Interaction: No interactive elements (maybe a tap to skip if loading is long, but likely not
needed if kept ~2 seconds).
Notes: Keep splash screen to ~2-3 seconds to not keep user waiting. Use this as an opportunity to
make a good first impression with the app’s branding style. Also, ensure the splash looks good on
various screen sizes (centered content).
2. Onboarding & Tutorial
•
•
•
•
Description: A short onboarding sequence for first-time users, guiding them on how to play and
highlighting key features. We want new users to grasp the game rules (especially if they haven’t
played charades before) and app navigation quickly.
Contents: This could be a series of 2-4 swipeable pages or a single scrollable tips page. For example:
Welcome Slide: “Welcome to [AppName]! The hilarious party game where you guess the word on
your forehead.” accompanied by a fun illustration.
How to Play Slide: Show an image of a person holding the phone to forehead and friends around.
Explain: “Pick a category, hold the phone to your head, and let your friends give you clues. Tilt down
if you guess right 34 12
, tilt up to pass! Don’t forget to act out and have fun!” – with arrows
indicating the motions.
7
•
•
•
•
Controls & Features Slide: “Use tilt or tap for correct/pass, and see your score at the end. The app
will even video-record the fun (optional) so you can share the laughter! 8
” This slide can also
mention the option to play in teams or online.
Monetization/Opt-in Slide (Optional): Optionally, inform “Watch short videos to unlock more decks
or go ad-free with premium. We keep the game free thanks to ads 6
– thank you for
understanding!” and perhaps allow user to toggle personalized ads consent here for GDPR.
User Interaction: Users swipe through or tap “Next”. Provide a “Skip” option to jump straight to app
(some may be already familiar). At the end, have a clear “Let’s Play!” button. Possibly include a
toggle “Don’t show tutorial next time”.
Notes: The tutorial should be skippable and also accessible later (e.g. via a “How to Play” button on
main menu for refresh). It must be concise – users likely want to jump into playing quickly. Use
visuals over text where possible (maybe cartoon illustrations demonstrating tilt up/down, etc., since
a user in a party might not want to read much). Also, ensure any video autoplay or heavy media is
avoided here to keep it lightweight.
3. Language Selection Screen (if applicable)
(This screen appears if we want the user to choose language explicitly, otherwise language can be a setting.)
- Description: Allows the user to select their preferred language for the app UI and possibly content. Could
appear on first launch (especially if device language is not one we fully support or if we want to highlight
multi-language support).
- Contents: A list of languages (in their native names, e.g. “English”, “Español”, “Français”, etc.) possibly with
country flags icons for clarity. The list could be shown in a scrollable modal or as part of onboarding. The
current selection is highlighted.
- User Interaction: Tap on a language to select. Perhaps a confirmation button (“OK” or “Continue”) to
proceed once chosen. If shown as part of onboarding, selecting language might immediately switch the
tutorial text to that language.
- Notes: Ensure this list is not overwhelming; we might show top 5-10 languages and an “More…” if we
support a lot. Because the official Heads Up supports dozens of locales 5
, we can aim to at least support
major languages at launch. This screen should be accessible later via Settings as well, in case a user wants
to change language.
4. Home Screen (Main Menu)
•
•
•
•
•
•
Description: This is the central hub screen that the user sees after launching (post-tutorial). It
should be simple and inviting, offering clear entry points to start playing and access other features.
Contents: The home screen will include:
App Title/Logo: A banner or logo at the top, reinforcing branding. Possibly an avatar/mascot image
(like someone holding a phone to head) to reinforce the game’s identity.
“Play” Button: The most prominent element – a big, attractive button that takes the user to the
category selection to start a game. It could say “Play” or “Start Game”.
Quick Start Option: We might also include a one-tap quick start for returning users – for example,
“Quick Play: Last Used Deck” or “Random Deck” – to jump into a game immediately without browsing
categories. This can increase engagement by reducing friction.
Menu Options: Other navigation buttons/icons such as: Categories/Decks (if not directly part of
Play flow), Custom Deck (if we highlight that separately), Teams/Multiplayer (to set up team mode
or online game), Achievements/Leaderboards (if implemented), Settings, Store (for purchases).
8
•
•
•
•
We will prioritize what’s shown as primary vs. maybe tucked in a hamburger menu or as icons. For
instance, “Settings” might be a small gear icon in a corner, whereas “Decks” or “Play” are big.
Promo Banner: There could be a section for announcements or new content (“New Deck available:
Movies!”) or a rotating carousel highlighting things like “Try Multiplayer with friends!” or seasonal
promotions. This area must be easy to update via remote config.
Ad Banner: If using banner ads, the main menu is a place we can display a small banner at the
bottom without interfering with core actions. (Labeled as “Contains ads” on store 35
). This will
generate revenue continuously during idle moments on the menu.
User Interaction: The main interaction is to tap “Play” and navigate to starting a game. Secondary
interactions include going to settings or other features. Everything should be reachable in one tap
from this main menu if possible.
Design Notes: As shown in the example image above, the main menu will use large buttons and an
illustrative graphic to instantly convey the fun nature. It should not feel cluttered; focus on the
primary action (playing). If too many features exist, consider a two-tier menu (e.g., a “More” button
or tabs) to avoid overwhelming the user. The “How to Play” info should be accessible here (maybe a
small “?” icon or as part of settings) for users who skipped or forgot the tutorial.
5. Category Selection Screen
•
•
•
•
•
•
•
•
Description: After the user chooses to start a game (via Play), they need to pick a category (deck of
cards). This screen lists all available decks, possibly grouped by type or popularity. It is a core part of
the user flow because the choice of category defines the content of the game.
Contents:
Category List: A grid or list of category cards. Each category entry shows the category name (e.g.
“Animals”) and an icon or thumbnail (like an animal icon). If a category is premium/locked, it will have
a lock icon or a different style indicating such. If the categories are numerous, we might group them
into collapsible sections (e.g. “Free Categories”, “Premium Categories”, “Custom Decks”).
Search/Filter: If we have 40+ decks, a small search bar or filter dropdown (by genre or age group)
can help users find a specific deck. For example, filter by “Kids”, “Pop Culture”, etc.
Deck Details Pop-up: (Optional) Tapping on a category could either immediately select it or show a
pop-up with more details (description of that deck, e.g. “Act It Out: Mimic the actions without
speaking!”). In the pop-up, an option to start or a back button to choose another. However, to reduce
friction, we may simply start immediately on tap for most decks, and only use a pop-up if the deck is
locked or if the user has to confirm purchase/unlock.
Custom Decks Section: If user has created custom decks, those should appear here as well
(perhaps under a heading “My Decks”). There could also be a button “Create New Deck” here, which
takes the user to the Custom Deck screen (see below).
Ad Placement: Possibly another banner ad at bottom if not used on main menu, but if one is
already on main menu, we might avoid doubling up ads. The category screen might remain ad-free
or reuse the banner area from the main layout. If an interstitial ad is to be shown, one could trigger
after category selection before the game starts (but this might annoy users right as they’re about to
play, so we might avoid that; showing after the round is preferable).
User Interaction: The user scrolls through categories and taps the one they want. If a category is
locked, tapping it will prompt either “Watch ad to unlock this round” or “Purchase to unlock
permanently” (with a clear explanation and prices). If the user confirms or watches an ad, the deck
becomes available (at least for that session). If the category is free or already unlocked, tapping it
goes to the Game Start/Countdown.
9
•
Design Notes: We want this screen to be visually exciting – each category card can have a distinct
color scheme or icon making the selection feel fun. For example, “Animals” could have a green card
with a cute animal icon, “Movies” a clapperboard icon, etc. The layout should accommodate different
screen sizes, possibly showing a grid on tablets vs. a list on smaller phones. We must ensure text is
readable (some users might be quickly picking a category in a loud environment). A snippet from a
similar app shows categories with icons like animals, fruits, tools, etc., and even a note that you can
change settings like number of cards from here.
Example: A category selection screen from an existing charades app. Our design will use a grid of colorful
category cards with icons (as illustrated above) so users can easily browse and pick a deck. Locked or premium
decks will be indicated clearly (e.g., grayed out or with a lock symbol).
6. Game Setup / Pre-Play Options
•
•
•
•
•
•
•
•
Description: Before the round actually starts, the app may present a quick “setup” overlay or screen
to configure the current game session. This can include options like number of rounds, team
selection, and a start countdown.
Contents:
Team Selection (if applicable): If the user chose Team Mode on the home screen or toggles it here,
show which team is up (Team A or Team B). Possibly allow entering team names or selecting which
team will play first. The interface could simply say “Team A’s turn!” with a small label so everyone
knows. If not in team mode, this isn’t shown.
Round Settings: Allow the user to adjust the number of cards (or time) for this round, if we want to
present that each time. Alternatively, this could be set once in Settings and default thereafter. To
reduce steps, we might not ask each time; we might assume a default round length and have a
“Game Settings” button if they want to change it. For simplicity, initial version may skip a dedicated
setup screen and just use defaults to start immediately – but we describe it here in case these
options are needed.
Start Prompt: A clear prompt like “Place the phone on your forehead to begin!” or “Get ready!” will
be shown. Possibly accompanied by on-screen instructions reminding how to indicate correct/pass
(especially for first-timers, e.g., a small image of tilt down/up icons). We can use this moment to ask
for camera permission if video recording is enabled (“Smile! We’ll be recording your round so you can
save or share the laughs – allow camera?” with a checkbox).
Countdown: Once the user is ready, they tap a start button (or simply put the phone on forehead
which could trigger via proximity sensor or a tap by a friend). Then a 3-2-1 countdown begins,
possibly with large numbers on screen and a beep or countdown ticking sound. This gives the
guesser time to position the phone and signals the game is about to start.
User Interaction: Confirming teams or settings, then tapping “Start” (or a big button like “Start
Round”). After the countdown, the game transitions into the gameplay screen automatically.
Notes: We should keep this pre-game phase brief. Ideally, it’s just a single tap from category
selection to game start. Only if team mode or special settings are in play do we add a bit of UI here.
It might even be a modal overlay (“Team A ready? Start in 3..2..1..”). If we need to fetch ads or data, a
short delay could be masked by the countdown.
7. Gameplay Screen (In-Game Interface)
•
Description: This is the screen displayed during the charades gameplay round. It is one of the most
critical screens, as it needs to be clearly readable by the people giving clues and easily understood by
10
•
•
•
•
•
•
•
•
•
•
the guesser (holding the device). The UI here should be uncluttered, focusing on the word to guess
and the essential indicators (timer, etc.).
Contents:
Word/Phrase Display: The current word or phrase is shown in very large font in the center of the
screen, oriented such that it’s readable to the clue-givers (which typically means it appears upside
down to the person holding it on their forehead, depending on orientation). Alternatively, we might
choose to always show it right-side-up to the device holder, assuming they’re not looking (traditional
charades they wouldn’t look). However, some people do glance at the screen when tilting to see what
the next word was. Heads Up shows it oriented normally because usually the guesser doesn’t peek
until after. We can decide orientation, but readability is key.
Category & Clue Info: A smaller label indicating the category name could be placed at the top or
bottom (e.g., “Category: Animals”). This reminds players which theme the clues are about. Possibly
an icon next to it. If the category has special rules (like “Act It Out – No talking!”) we might show a
small hint or icon for that too.
Timer: A countdown timer is displayed, likely at a corner or as a circular progress bar around the
word. For example, a 60-second countdown that is very visible to the clue-givers so they know how
much time is left. In the last 10 seconds, it might flash or change color to increase urgency.
Score Indicator: If we want to show ongoing score (how many correct so far in this round), we can
have a small number somewhere (“Score: 5” as they’re playing). However, this might not be necessary
to display during play, as it could distract; often players just focus on the next word. We could just
count internally and show score at the end.
Correct/Pass Feedback: When the user tilts the device or presses a pass/correct button, the app
should give immediate feedback: e.g., on correct tilt (down), flash green with a and maybe briefly
show the word as “Correct!” then quickly auto-switch to next word; on pass (tilt up), maybe flash
orange with a “Skip” message and then next word. This transition should be snappy – possibly
accompanied by a card flip animation to the next word. The camera should also adjust if needed
(some games show the word after the guesser tilts down so they can see what it was they got right,
then it moves on – we can consider doing that for a second). The UI will play sound effects for
correct/pass to reinforce it.
Pause/Exit Controls: There should be a way to pause or end the round if needed (maybe the user
can touch the screen with two fingers or press a small pause button, since accidentally pausing
could be an issue if just tapping). Pausing would freeze the timer and perhaps show an overlay with
options “Resume” or “Quit”. This is mostly for emergency stops or if the game needs to be halted.
Video Recording Indicator: If video recording is enabled, a small recording dot or camera icon
could show, indicating the front camera is capturing. We will need to hide any UI overlays in the
recorded video or capture only the outward camera view, depending on how we implement (likely
we capture front cam for reactions). Technical detail aside, we just ensure the user knows when they
are being recorded (for privacy transparency).
User Interaction: During gameplay, the guesser’s main interaction is through tilting the device (or
tapping if necessary). Clue-givers interact off-app by giving verbal or physical clues. The user holding
the phone ideally doesn’t need to tap the screen at all (to keep it hands-free); that’s why
accelerometer gestures are central. If the app senses no movement for a while, maybe a hint on
screen like “Remember, tilt down for correct!” could appear to guide them. At the end of the timer,
the round ends automatically. If the user wants to end early, they could pause/quit.
Design Notes: The gameplay screen should have high contrast (often white text on a dark
background or vice versa) because it may be seen from a distance by the group. A popular design is
a solid color background that might even match the category theme (e.g., green background for
Animals, etc.) to add variety. But ensure the text stands out. We should also handle orientation
11
changes: if the user accidentally has rotation on and turns their phone, we lock orientation during
gameplay to avoid confusion. Additionally, since this screen is held up to foreheads, ensure nothing
crucial is at the extreme top of the screen (some phones have notches or camera cutouts – though it
will be facing outward, we just have to layout properly). The UI elements like timer can be in corners
so as not to block the word or be blocked by any phone hardware.
8. Results Screen (Post-Game Summary)
•
•
•
•
•
•
•
•
Description: After each round, a results or summary screen is shown. This congratulates the player/
team on their performance and shows details of what happened in the round. It’s also a pivot point
where the user can decide to play again, switch decks, or share their outcome.
Contents:
Score Summary: Prominently display “You scored X points!” or “[Team A] scored X!” in a celebratory
style. This is the number of correct guesses from that round. If playing in teams and the game is
ongoing, show perhaps “Team A: 7 points this round (Total: 15)”. If the round ended some match (like
after a certain number of rounds), declare the winner (“Team A wins!”).
List of Words: Show a list of all the words from that round, separated into “Guessed” (correct) and
“Passed” (skipped/missed). This list often generates laughter as players recall those moments (and is
good for letting them know what they missed). For example, under Guessed: “Cat, Banana, Eiffel
Tower…” and under Passed: “Donald Trump, Hula Hoop…”. If we recorded video, these words can be
time-stamped to the video for a replay effect, though that’s an advanced feature.
Replay Video Thumbnail: If video recording was on, display a thumbnail or embedded small video
player of the round’s recording. Users can tap to play the video to see the funny moments. Provide
options to Save to device and Share to social media. Sharing triggers the platform’s share sheet
(Facebook, WhatsApp, etc.), and saving stores it in their gallery. This feature is a highlight as it
extends engagement beyond gameplay itself 8
. If no video was recorded, perhaps a generic
graphic can be here instead, or just omit this section.
Buttons – Next Actions: Key actions include: “Play Again” (replay the same deck, maybe for another
person’s turn), “New Deck” (go back to category selection), and if in team mode and game not over,
“Next Team’s Turn” (which would jump straight to gameplay with the other team without needing to
re-pick category). Also, an explicit “Home” button in case they want to exit to main menu. If team
mode was on and we reached a planned number of rounds, maybe a “Final Scores” screen could be
just this results if it’s final, or an intermediate if not final.
Ad Display: The results screen is a logical place to show an ad after the round is completed (when
the tension is over). We can present an interstitial ad here, since the user is not in the middle of
action. We might do it every round or every couple of rounds. Given the balance we want, perhaps
after every round if the rounds are long (60s) might be acceptable, but if users find it too frequent,
maybe every 2 rounds. We will monitor feedback. If an interstitial is shown, it would appear either as
soon as the round ends (before showing the results), or as a framed ad within the results screen.
Another approach is offering a rewarded ad here: e.g., “Watch an ad to double your points or earn a
bonus” (though doubling points doesn’t mean much unless points are currency, which they’re not
here). More fitting would be “Watch an ad to get an extra 30 seconds in your next round” or “to
unlock a premium deck for the next game free.” These could be presented on the results screen as
options.
User Interaction: On this screen, the user will likely review the words and then choose their next
action (replay or new game, etc.). If they want to share the video or score, they’ll tap those buttons
and follow through the system dialogs. If an ad pops up, they’d have to close it after it finishes to
12
•
proceed. We must ensure the flow continues gracefully after an ad (returning to this results screen
or moving to the next chosen screen).
Design Notes: This screen should feel rewarding and positive. Use celebratory graphics (confetti,
stars, etc.) and perhaps the color theme of the category or team. It’s the moment of payoff, so
emphasize the score with large text. The list of words can be scrollable if long. Keep the layout such
that on smaller devices the key info (score and main buttons) are visible without scrolling, and the
list or video can scroll below. If team mode, maybe use columns or separate sections for each team’s
points. We should also be careful that any social sharing complies with privacy (if a video includes
people, ensure they consent to share). The app can include a disclaimer about video use.
9. Custom Deck Creation Screen
•
•
•
•
•
•
•
•
•
Description: This screen (or screens) allows the user to create and manage their own custom decks
of words. It’s an advanced feature for power users, but can greatly increase engagement as users
tailor the game to their interests (and likely spend more time in-app curating decks).
Contents:
Deck List/Management: If multiple custom decks are allowed, the first view might list your created
decks with options to edit or play them. If only one at a time, we go straight to creation. Let’s assume
multiple: the screen shows “My Decks” with each deck name and maybe number of cards, and a
button “Create New Deck”.
Create New Deck Workflow: When creating a new deck, user will input: Deck Name (text field, e.g.
“Family Inside Jokes”), and then a way to add cards. We can have a simple textbox to type a word and
press + to add to list. This continues in a list builder format. Alternatively, allow multiline paste
(“paste a list of words, one per line”). We should also allow deleting or editing entries before saving.
The UI might be two columns on tablets (list of entries on one side, input on other).
Saving/Using Custom Deck: Once done, the user saves the deck. It then appears in the category
selection list under “My Decks”. Optionally, prompt “Add more cards later anytime.” If an account
system exists, offer to backup online (or require login to create decks if syncing is a concern).
Editing Deck: Tapping an existing custom deck might allow editing the list (add/remove cards) and
renaming or deleting the deck.
Sharing Deck (Optional): We could include a share/export feature (like generate a code or link that
others can use to import this custom deck into their app), fostering community content sharing. This
is optional stretch goal.
User Interaction: Mostly form filling and list management. Use standard interactions (keyboard for
typing words, plus buttons, swipe to delete perhaps). It should be straightforward so that even on a
phone, adding, say, 20 custom words isn’t too tedious. Possibly integrate with voice input (user could
speak a word to add, leveraging speech-to-text, which might be a neat UX for quick input, but not
required).
Design Notes: Keep the design clean and utilitarian here, but still on theme. For example, use the
same font for text fields, maybe a faint lined-paper background when listing words to give a sense of
a list. Ensure the text fields are not hidden by the on-screen keyboard (use scrollable views). Provide
help if needed (like an example of what makes a good deck or a count of how many words is good;
maybe suggest at least 10 words for a decent game). If needed, put a limit to number of cards (or no
limit, but maybe performance wise we don’t expect more than, say, 100 per custom deck).
10. Settings Screen
•
Description: A screen where users can adjust various preferences and find auxiliary information.
13
•
•
•
•
•
•
•
•
•
•
•
Contents:
Sound & Haptics: Toggle switches for sound effects on/off, music on/off (if background music
present), and vibration on/off. This allows those who want a quieter game (or are streaming to a call)
to silence the app.
Content & Difficulty: Options like “Kid-Friendly Mode” – when enabled, the app will either filter out
any mature content or highlight only the easy decks. This addresses the age-appropriate concern
10
. Could also include a toggle for “Show words after pass” (some might want to see the word they
skipped, others might not care). Difficulty levels could be an option if we categorize cards by
difficulty; e.g., “Normal vs. Hard” mode for decks (maybe not needed initially).
Language: If not handled on a separate screen, the setting to change app language can be here. It
would list available languages (similar UI to language selection screen).
Account: If we have login, show logged-in user info and options like “Log out” or “Sync now”. If not
logged in, perhaps a “Sign in to save your progress” prompt.
Restore Purchases: On iOS especially, a button to restore purchases (for those who bought remove-
ads or deck packs) is required. Android typically auto-restores, but we can include it for parity.
Help/How to Play: A menu item to view the tutorial or a help FAQ. Tapping this could replay the
onboarding slides or open a small guide with Q&A (like “How to play via video call?”,
“Troubleshooting tilt issues”, etc.).
Contact/Feedback: An option like “Send Feedback” or “Support” which could open an email or form.
Not heavily used but good to have for user support.
About & Legal: Information like app version, credits (e.g., “Powered by Unity” if applicable), Privacy
Policy link, Terms of Use link, and ad choices (especially because of AdMob we need an “Ad Choices”
or privacy info link 36
). For example, “Privacy Policy” opening a webview, etc.
User Interaction: Users can scroll through settings and toggle or tap into sub-options. Everything
should take immediate effect (toggles) or navigate to a sub-screen (like Language selection or
Account login). We’ll make sure a back navigation is obvious (since settings might be a sub-screen
launched from the main menu, typically a top bar with a back arrow or swipe gesture to go back).
Design Notes: Settings are usually straightforward. We’ll follow a standard mobile settings layout
(list of items, maybe using the native styles for iOS and Android respectively, or a unified custom
style). Even here, maintain the app’s visual theme (color accents for switches, etc.) but focus on
clarity. Group related settings with headers (Audio, Game, Account, etc.) for organization.
11. Store/Purchases Screen
•
•
•
•
•
•
Description: If the app includes in-app purchases beyond a simple “Remove Ads” button, we’ll have a
store screen. This allows users to buy premium content or subscriptions.
Contents:
Ad Removal: Clearly list the option to remove ads (with price). If already purchased, indicate that
(and disable/hide purchase button).
Deck Packs: Show available premium decks or deck bundles with names, descriptions, and prices.
For example, “Superheroes Pack – 50 cards of Marvel & DC characters – $1.99”. We can have
thumbnails or icons for each. Possibly a “Buy All Access” option if many packs exist.
Subscription Offer: If we go with a subscription model, highlight it: e.g., “Party Pro Membership:
Unlock ALL decks, remove ads, and get exclusive new decks monthly. $4.99/month or $29.99/year.”
Provide a button to subscribe and mention any free trial if given.
Restore/Help: Reminders that purchases restore on reinstall or across devices when logged in. We
might integrate the restore in settings as mentioned, but could also have a note here.
14
•
•
•
Currency/Payments: It will use the platform’s IAP, so UI should follow guidelines (don’t use custom
purchase dialogs, use Google/Apple flows on button press). Prices will be localized automatically by
store.
User Interaction: Tapping a purchase will trigger the OS in-app purchase confirmation. After
purchase, we update the UI (unlock things, remove ads, etc.). If the user cancels or fails payment,
handle gracefully (message or none).
Design Notes: The store should be appealing but also clear on what the user gets. Use visuals for
deck packs. Possibly incorporate some trust elements (“Official content” or ratings). Not too pushy;
it’s there for those interested. Ensure that non-paying users can ignore it and still enjoy a lot of free
content (this is important for goodwill). We might show a subtle red dot on the store icon when new
content is available to entice visits.
Additional Considerations
•
•
•
•
•
Performance: The app should run smoothly on a wide range of devices (Android 7.0+ and iOS 12+ as
a baseline, for example). Heads Up is around ~167 MB on Android 37
, but we will aim to optimize
asset sizes to keep download size reasonable. Use of game engines (Unity/Flutter) is possible, but
ensure no noticeable lag in UI, and that tilt sensing is real-time.
Analytics & User Feedback: Integrate analytics to track feature usage (e.g., which categories are
played most, drop-off points in onboarding, ad engagement, etc.). Also consider a prompt after a
few days for rating the app (to gather positive reviews, boosting our store ranking).
Privacy: Since we collect video (user’s front camera recordings) and show ads, we must handle user
data carefully. No videos are uploaded to our servers without user action; they remain local unless
shared by user. AdMob integration means we should present a consent dialog for personalized ads
in regions like EU 31
. We will have a Privacy Policy detailing all this.
Testing: We will conduct extensive QA, including testing gameplay in various real-world scenarios
(different lighting for video, different noise levels to ensure sounds are audible, multiple people
shouting might create confusion with voice recognition if we had any voice features – currently not
using voice recognition, it’s all human-driven clues). We’ll also test tilt on different devices to
38
calibrate. Multiplayer (if included) will be tested for latency and sync issues .
Launch Plan: Upon finalizing development, the app will be published to Google Play Store and Apple
App Store. We will prepare compelling store listings with screenshots showing people playing and
the UI (highlighting our attractive design), and possibly an promo video. We will emphasize
keywords like “charades, party game, Heads Up, word guess” for ASO 39
. Post-launch, timely
updates with new content and improvements based on user feedback will be critical to maintain a
high rating and growing user base.
Conclusion
In summary, this PRD specifies a comprehensive charades party game app inspired by the famous Heads
Up! game. By focusing on user-friendly UI, engaging features, quality content, and smart
monetization, we aim to deliver an app that users love to play at gatherings and share with their friends.
The screens and features described will ensure the app is fun, easy to use, and competitive with top
industry apps in this space. With careful attention to user experience (as evidenced by the success of
colorful, intuitive designs in similar apps 3
) and a balanced approach to ads and IAP (learning from what
15
users appreciate and dislike the long term.
7 6
), our app will not only attract a large audience but also retain them for
By executing on this PRD, the result will be an “extremely good app” that engages users deeply, keeps
them coming back for more rounds of laughter, and generates revenue to sustain its growth – truly aligning
with the goal of an industry-level, user-centric mobile game experience.
Sources:
1. 2 8
Official Heads Up! app description and features
2.
Digittrix – HeadsUp Game App: Development Process & Cost Breakdown (features of a Heads Up style
game)
19 4
3.
CIS – How to Develop Heads Up Charades (monetization and design considerations for charades apps)
6 3
4. 21 33
Google Play Store – Charades! (Heads Up & Game Fun) (example clone app features)
5.
Usercentrics – AdMob for Games Monetization Guide (best practices for rewarded ads improving
engagement)
24 26
1 4 19 20 28 38 39
HeadsUp Game App Development: Process & Cost
https://www.digittrix.com/blogs/headsup-game-app-development-process-cost-breakdown
2 5 8 9 12 14 15 16 17 18 34 36 37
Heads Up! 4.9.6 (Android 7.0+) APK Download by Warner
Bros. International Enterprises - APKMirror
https://www.apkmirror.com/apk/warner-bros-international-enterprises/heads-up/heads-up-4-9-6-release/heads-up-4-9-6-
android-apk-download/
3 6 7 10 13
How to Develop Heads Up Charades For Kids App
https://www.cisin.com/growth-hacks/cost-and-feature-to-develop-software-like-heads-up-charades-for-kids/
11
Charades App : r/AppIdeas - Reddit
https://www.reddit.com/r/AppIdeas/comments/1bad4zo/charades_app/
21 22 33 35
Charades! Heads Up & Game Fun - Apps on Google Play
https://play.google.com/store/apps/details?id=com.MobileUpHeadImages.JawalkAliRaskCards&hl=en_US
23
Good ad placement practices? : r/admob - Reddit
https://www.reddit.com/r/admob/comments/1dx0fom/good_ad_placement_practices/
24 25 26 30 31 32
AdMob for Games: Ultimate Mobile Game Monetization Guide
https://usercentrics.com/knowledge-hub/admob-increase-mobile-game-monetization-with-user-consent-guide/
27
How to Develop Heads Up App - Cyber Infrastructure, CIS
https://www.cisin.com/growth-hacks/cost-and-feature-to-develop-software-like-heads-up/
29
Mobile Ads: the Key to Monetizing Gaming Apps - Google AdMob
https://admob.google.com/home/resources/monetize-mobile-game-with-ads/
16