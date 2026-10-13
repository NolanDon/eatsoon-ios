# Review response draft: EatSoon

1. Function and problem: Review items extracted from a fridge photo, confirm label dates or suggested check intervals, then log used items.

2. Intended audience: Households tracking food in a fridge, freezer or pantry.

3. Market need: This is a focused alternative with a distinct workflow, not a claim that no competing apps exist. Suggested dates are estimates, not food safety guarantees. The accompanying research identifies existing competitors. Market demand still requires intended user testing.

4. Actual testing: Before the original rejected submissions, the only reported human testing was the developer running the apps daily on their own iPhone. No independent beta cohort or specific pre-rejection feedback changes were documented. After V2, the developer reported repetitive homepages, excessive text, small buttons, inconsistent heading sizes, an unwanted serif font and a mismatched KnitTally splash palette. V3 applies that owner feedback through distinct minimal dashboards, large short actions, a clear title hierarchy, new fonts and matched splash/icon colors. These are developer feedback changes, not claims of independent user validation. V3 technical validation includes automated logic/widget tests, all ten native simulator runs, server/provider checks and separate macOS Vision tests. The phone was disconnected, so fresh physical V3 camera/App Attest testing is not claimed.

5. Suite: Ten apps under Boxill Apps. Wearloom organizes clothing; EatSoon tracks food; Doodlebook creates drawing comics; Fitway compares furniture measurements; KnitTally tracks knitting guides and rows; Odoly logs vehicle service; Stubloom archives events; ScaleRecipe drafts recipes; Tendly logs plant care; Weekstash tracks savings and payday plans.

6. Consolidation: Each app owns different records, actions and intended users. Shared technical infrastructure could support a combined product, but these specialized workflows are currently separate. This does not guarantee guideline 4.3 acceptance.

7. Shared components: Flutter, common billing and review utilities, a versioned local store, backup validation, photo input/consent, App Attest client, onboarding/paywall shell, mascot display, native photo processing and a typed AI gateway. Their role is infrastructure; the primary dashboards and domain rules differ. Five poses and a visual reskin alone are not the substantive differentiation.

8. Third party components: Standard Flutter plugins, RevenueCat, Google Gemini, Apple Vision and licensed Google Fonts. No third party commercial app generation service or third party app content library has been identified. Backend photo test fixtures are attributed independently and are not bundled as app content.

9. Ownership: The developer states these are their own brand and account, with no client or partner supplying the concepts, branding or content. They are submitted by Boxill Apps, the content provider.
