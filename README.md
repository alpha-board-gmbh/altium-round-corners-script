# altium-round-corners-script
We created a small Altium script to solve a common PCB design annoyance: easily adding precise fillets (tangent arcs) to trace connections. Altium Designer is a professional EDA tool to design printed circuit boards, s. [Altium Website](https://www.altium.com/).

⛔️ Problem: Manually creating perfect tangent fillets between traces or traces and existing arcs in Altium is tedious. You have to estimate tangent points, manually place arcs, and trim traces.

✅ Solution: Our Universal Fillet Tool ➜ This script automatically adds perfect fillets with a specified radius with a single click.

## How to Install:

- Add the Script to Global Projects: In Altium, go to Preferences -> Scripting System -> Global Projects and click "Install...". Select the script file (Fillet_Track_Arc_Round.PrjScr). (see: ![Adding a script in Altium settings](https://github.com/user-attachments/assets/53d7bcec-87ce-4e50-8ec4-ec05c229c59f)
- Customize the Menu: To add the script to your Altium toolbar, right-click on the toolbar area and select "Customize". Under "Categories" select "[Scripts]". Then drag the Fillet_Track_Arc_Round.PrjScr > CreateUniversalFillet command to the Toolbar. (See: ![Add Button to Toolbar](https://github.com/user-attachments/assets/73fbb849-64b4-4adf-be43-8a25e6910850) and ![Menu Settings](https://github.com/user-attachments/assets/0bdfad91-4840-4e9d-9082-ded7363a03e9)
- (Optional) Add a Menu Icon: You can edit the Command in the "Customize PCB Editor" Dialog and add a icon. This makes it easier to find. (See: ![Menu Icon](https://github.com/user-attachments/assets/1170d6b4-8389-44ab-8455-15a48076b935)

## How it works (Filleting a Corner in Altium Designer):

1. Select the corner you want to fillet (either two connected straight traces or a straight trace connected with an arc).
2. Click the new button in the Altium menu bar. (See: ![Fillet Button Usage](https://github.com/user-attachments/assets/1c6f660d-c551-4058-b11d-9d5706fb1773)
3. Enter the desired radius in millimeters.
4. The script calculates the vector geometry, adds the perfect arc, and trims the original traces automatically.

**Example Results**: These images show before and after examples of the script in action.

- ![Example 1](https://github.com/user-attachments/assets/a9904f6b-c0a1-411f-b50c-052a009bbdac)
- ![Example 2](https://github.com/user-attachments/assets/221cd296-dc60-4385-aeb4-7584803859e9)
- ![Example 3](https://github.com/user-attachments/assets/bad12625-2d66-4d63-ad11-157c3fcf44d6)
- ![Example 4](https://github.com/user-attachments/assets/a9e5117a-27fb-439b-a9e2-1d7c8287c4cf)

## Benefits

- Saves time
- Creates clean, overlap-free transitions
- Ideal for aesthetic layouts, RF designs, and tight spaces.
