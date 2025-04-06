# Chocobo Racing Automation Script

This SND Lua script automates chocobo racing in FFXIV. It queues up races via the Duty Finder, executes race logic with randomized in-race inputs (for anti-detection), and retrieves your chocobo's rank and training info from the Gold Saucer. The script supports both starting fresh from outside a race and continuing if already in a race zone.

## Features

- **Automatic Duty Queueing:**  
  Opens the Duty Finder, clears previous selections, and selects the appropriate duty based on your chosen race type.

- **Race Execution:**  
  Handles initial side-drift and in-race key presses with randomized timing to simulate human behavior.

- **Chocobo Info Retrieval:**  
  Opens the Gold Saucer to fetch your chocobo's rank, name, and available training sessions. The script stops when your chocobo reaches the target rank.

- **Dual Start Handling:**  
  Detects if you're already in a race zone and either queues or proceeds directly to race execution.

- **Configurable UI Speed:**  
  Adjust UI delays to suit slower or faster PCs without affecting critical in-race timings.

- **Race Type Selection:**  
  Choose from `random`, `sagolii`, `costa`, or `tranquil`. For random races, the script checks for any of the three valid zone IDs.

## Configuration

The only user-configurable settings are:

- `maxRank`: The target chocobo rank at which the script will stop.
- `raceType`: The race type to run. Valid options are:
  - `random`
  - `sagolii`
  - `costa`
  - `tranquil`
- `speed`: Set to `"fast"` or `"slow"` for UI handling delays.

All other parameters (e.g., wait times, duty selection indices, zone IDs) are managed internally.

## Usage

1. **Install SND:** Ensure SND is installed and configured for FFXIV.
2. **Load the Script:** Paste the complete script into your SND macro editor.
3. **Configure:** Adjust `maxRank`, `raceType`, and `speed` in the configuration section as desired.
4. **Run the Script:** Execute the macro. The script will automate the queueing, race execution, and chocobo info retrieval while logging progress in your chat.

## Disclaimer

**Use at your own risk.** Automation in FFXIV may violate the game's terms of service. The author is not responsible for any consequences arising from the use of this script.

---

Happy Racing!
