# Chocobo Racing Automation Bot for FFXIV

This Lua script automates the **Chocobo Racing** process in **Final Fantasy XIV** using the **SomethingNeedDoing (SND)** plugin for the Dalamud framework.

The bot automates:
- Chocobo race queuing
- Selecting Sagolii Road (Gold Saucer)
- Sending appropriate key presses during races
- Handling post-race actions and checking for **Rank 40**

Once Rank 40 is reached, the bot will **automatically stop** racing.

## 🚀 Features

- **Auto-selects Sagolii Road**: Automatically selects the Chocobo race course **Sagolii Road** only once during each session.
- **Race Management**: Waits for races to start, performs key presses like `KEY_1` and `KEY_2` at intervals, and manages race timing.
- **Movement Handling**: Ensures smooth movement throughout the race by constantly holding the **W key** with no delays after key presses.
- **Post-Race Handling**: After each race, the bot waits for the result screen and exits the race smoothly.
- **Rank 40 Stop**: Once your Chocobo reaches **Rank 40**, the bot will stop automatically to prevent over-racing. 

## ⚙️ Setup

### Prerequisites

1. **Final Fantasy XIV** installed and running.
2. **SomethingNeedDoing (SND)** plugin installed for the Dalamud framework.
3. **Lua environment** compatible with SND (ensure you have Lua scripting enabled).

### How to Use

1. Install **SomethingNeedDoing (SND)** if you haven’t already. You can find it in **FFXIV's Dalamud plugin repository**.
2. Download this script and place it in your **SND script folder**.
3. Run the script with **SND** to begin automating your Chocobo races.

### How It Works

1. **Race Queuing**: The bot opens **Duty Finder** and queues for **Chocobo Racing** automatically.
2. **Sagolii Road Selection**: The bot will automatically select **Sagolii Road** the first time during each session.
3. **Race Execution**: It sends key presses at the appropriate times during the race for **speed boosts** and **key abilities**.
4. **Post-Race**: The bot exits the race after completion, checks your Chocobo rank, and stops at **Rank 40**.
5. **Infinite Loop**: The bot will continue racing until it reaches Rank 40, then it stops.

### Customization

- **Adjust Key Press Intervals**: You can modify the intervals for when the bot sends keys like `KEY_1`, `KEY_2` in the `key_1_intervals` array.
- **Change Race Course**: You can modify the course selection (Sagolii Road) if needed.

### Stopping at Rank 40

Once the bot detects that your Chocobo has reached **Rank 40**, it will stop automatically with the message:

```bash
🛑 Chocobo is Rank 40 — stopping script.
