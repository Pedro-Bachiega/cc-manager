# CC-Tweaked Computer Manager

A robust framework designed for managing a network of ComputerCraft computers within Minecraft. It establishes a client-server architecture where a central "Manager" computer orchestrates tasks for multiple "Worker" computers. Communication between manager and workers is handled wirelessly using ComputerCraft's `rednet` API. This project is designed to be run in the [CC: Tweaked](https://tweaked.cc/) mod for Minecraft.

## Architecture

The system is composed of two main types of computers:

*   **Manager Computer (`manager/src/manager/startup.lua`):**
    *   **Central Control:** Acts as the brain of the network. It discovers, tracks, and assigns roles to worker computers.
    *   **Worker Discovery & Registration:** Workers broadcast registration requests, and the manager acknowledges them, establishing a connection.
    *   **Role Assignment:** The manager can assign specific "roles" (e.g., "Advanced Mob Farm Manager", "Mob Spawner Controller", "Power Grid Monitor") to individual workers. These roles correspond to specialized scripts that workers execute.
    *   **Task Dispatching:** The manager can send commands and tasks to workers based on their assigned roles.
    *   **Status Monitoring:** Workers send periodic "heartbeats" to the manager, allowing the manager to track their online status and current activity. If a worker doesn't send a heartbeat for a certain period, it's marked as disconnected.
    *   **User Interface:** Utilizes the `compose` library (a dependency of this project) to provide an interactive UI for monitoring workers, assigning roles, and triggering actions.
    *   **Persistence:** Saves the assigned roles and worker states to files (`assigned_roles.dat`, `workers_state.dat`) to maintain configuration across reboots.
    *   **Concurrency:** Uses `parallel.waitForAll` to run multiple concurrent tasks, including UI rendering, network message listening, input handling, state saving, and worker status updates.

*   **Worker Computer (`manager/src/worker/startup.lua` and `manager/src/worker/roles/*`):
    *   **Self-Registration:** Upon startup, a worker attempts to register with a manager. If a manager ID is known (from previous sessions), it tries to connect directly; otherwise, it broadcasts a registration request.
    *   **Role Execution:** Once registered and assigned a role by the manager, the worker loads and executes the corresponding Lua script from its `src/worker/roles/` directory.
    *   **Task Execution:** The role script handles specific tasks (e.g., toggling a mob farm, monitoring power levels) and reports results back to the manager.
    *   **Heartbeats:** Periodically sends heartbeat messages to the manager to indicate it's still active and its current status.
    *   **Command Processing:** Responds to commands from the manager, such as updating its software, clearing its assigned role, or executing specific role-related actions.
    *   **User Interface:** Provides a basic UI (also using `compose`) to display its current status and manager connection.

## File Structure

```
cc-manager/
├── install.lua         # Universal installer script for both manager and compose projects
├── update.lua          # Script to update the manager/worker software
├── README.md           # This file
└── src/
    ├── common/
    │   ├── config.lua          # Handles loading and saving configuration data (JSON)
    │   ├── coroutineUtils.lua  # Provides utilities for managing coroutines (non-blocking delays)
    │   ├── network.lua         # Wrapper around the rednet API for simplified communication
    │   ├── protocol.lua        # Defines the network communication protocol and message types
    │   ├── ui.lua              # Common UI components built with the 'compose' library
    │   └── workerMessaging.lua # Core logic for worker-manager communication
    ├── manager/
    │   └── startup.lua   # Main script for the manager computer
    └── worker/
        ├── startup.lua   # Main script for the worker computers
        └── roles/        # Directory containing specialized worker role scripts
            ├── advanced_mob_farm_manager.lua
            ├── mob_spawner_controller.lua
            └── power_grid_monitor.lua
```

## Setup & Installation

The `install.lua` script handles the setup for both the `cc-manager` and `cc-compose` projects.

1.  **Host the files:** Upload the contents of this project (including the `compose` directory) to a web server or a GitHub repository.
2.  **Run the installer:** On each computer in-game, run the following command, replacing `<url_to_install.lua>` with the raw URL of your `install.lua` script.

    *   **On the Manager Computer:**
        ```lua
        wget run <url_to_install.lua> manager
        ```

    *   **On each Worker Computer:**
        ```lua
        wget run <url_to_install.lua> worker
        ```

3.  **Reboot:** The installer will download the necessary files and create a `startup.lua` file. Reboot the computer for the program to start.

## Usage

Once the computers are set up and rebooted:

*   **Worker Computers:** Will automatically find and register with the manager. They will then wait for tasks or role assignments.
*   **Manager Computer:** Its screen will display a list of connected workers and their status. You can interact with the UI to assign roles, send commands, and monitor the network.

## Worker Roles

The `src/worker/roles/` directory contains specialized scripts that define the capabilities of worker computers.

*   **`advanced_mob_farm_manager.lua`:**
    *   **Functionality:** Manages an automated mob farm. Controls its state (on/off) via redstone and monitors item counts in an attached inventory peripheral (e.g., a chest).
    *   **Interaction:** Can be toggled remotely by the manager. Displays farm status and item counts on its local monitor.
*   **`mob_spawner_controller.lua`:**
    *   **Functionality:** Controls a mob spawner's state (on/off) via redstone.
    *   **Interaction:** Can be toggled remotely by the manager. Displays spawner status on its local monitor.
*   **`power_grid_monitor.lua`:**
    *   **Functionality:** Monitors the power level of a specified energy cell (e.g., from the Powah mod) and can control connected machines via redstone based on commands from the manager.
    *   **Interaction:** Displays current power level and allows manager to add/remove controlled machines and set their redstone states.

## Dependencies

This project relies on the `compose` UI framework, which is automatically installed alongside the manager/worker scripts by `install.lua`.