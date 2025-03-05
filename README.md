# SuiteCRM Docker Installation Script

## Overview

This script automates the installation and setup of SuiteCRM using Docker Compose. It also provides functionality for managing backups and Docker containers. The script is designed to work on Ubuntu and Debian systems.

## Prerequisites

1. **Docker & Docker Compose**: Ensure Docker and Docker Compose are installed on your system.
2. **Gum**: This script uses gum for user-friendly CLI input. The script will automatically install it if not present.
3. **Supported Operating Systems**: Ubuntu and Debian (specific versions mentioned in the script).

## Features

- Automated installation of SuiteCRM with necessary configurations.
- Setup and configuration of MariaDB.
- Options for backup and Docker container management.
- User prompts for essential configurations like admin usernames and passwords.

## Usage

### Installation

1. **Clone the Repository**:
   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. **Run the Script**:
   Execute the installation script to set up SuiteCRM.
   ```bash
   ./install_suitecrm.sh
   ```

3. **Follow Prompts**:
   - Enter the project name.
   - Configure MariaDB username, password, and root password.
   - Set up SuiteCRM admin username and password.
   - Choose backup times and manage containers via the interactive menu.

### Main Menu Options

- **Install SuiteCRM**: Initiates the SuiteCRM installation and configuration process.
- **Make a complete archive of the database and website**: Schedule and create backups of the SuiteCRM setup.
- **Container management**: Manage running Docker containers.
- **Log out**: Exits the script.

## Directory Structure

- `mariadb-persistence`: Directory for MariaDB data persistence.
- `suitecrm-persistence`: Directory for SuiteCRM data persistence.
- `backups`: Directory where backups will be stored.

## Important Notes

- Ensure that your system meets the prerequisites before running the script.
- The script will prompt you for necessary input, ensure you provide this information accurately.
- Review and modify the `PROJECT_DIR` variable in the script to reflect your desired project directory path.

## License

This script is licensed under the MIT License.

## Contributing

Contributions are welcome. Please fork the repository and submit a pull request.

---

This README provides an overview and ensures users can effectively use and understand the functionality of the SuiteCRM installation script.
