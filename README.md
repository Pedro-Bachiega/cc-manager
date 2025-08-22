# CC-Tweaked Computer Manager

A simple framework for managing a network of ComputerCraft computers, with a central manager and multiple workers. This project is designed to be run in the CC:Tweaked mod for Minecraft.

## Architecture

The system is composed of two main types of computers:

-   **Manager:** The central computer that acts as the brain of the network. It discovers and keeps track of all available workers, assigns them tasks, and provides a status overview.
-   **Worker:** A peripheral computer that registers itself with the manager upon startup. It then idles until it receives a task, executes it, and reports the result back to the manager.

Communication is handled wirelessly using the `rednet` API.

## File Structure

```
cc-manager/
├── install.lua         # Universal installer script
├── README.md           # This file
└── src/
    ├── common/
    │   ├── protocol.lua  # Defines the network communication protocol
    │   └── utils.lua     # Shared utility functions
    ├── manager/
    │   └── startup.lua   # Main script for the manager computer
    └── worker/
        └── startup.lua   # Main script for the worker computers
```

## Setup & Installation

1.  **Host the files:** Upload the contents of this project to a web server or a GitHub repository.
2.  **Run the installer:** On each computer in-game, run the following command, replacing `<url_to_install.lua>` with the raw URL of your `install.lua` script.

    -   **On the Manager Computer:**
        ```lua
        wget run <url_to_install.lua> manager
        ```

    -   **On each Worker Computer:**
        ```lua
        wget run <url_to_install.lua> worker
        ```

3.  **Reboot:** The installer will download the necessary files and create a `startup.lua` file. Reboot the computer for the program to start.

## Usage

Once the computers are set up and rebooted, the worker computers will automatically find and register with the manager. The manager's screen will display a list of connected workers and their status.
