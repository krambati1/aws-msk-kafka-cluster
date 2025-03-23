#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect OS type
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian" # Debian, Ubuntu, and derivatives
    elif [[ -f /etc/redhat-release ]]; then
        echo "redhat" # RHEL, CentOS, Fedora
    elif [[ -f /etc/arch-release ]]; then
        echo "arch" # Arch Linux
    else
        echo "unknown"
    fi
}

# Detect the operating system
OS_TYPE=$(detect_os)
echo "Detected operating system: $OS_TYPE"

# Install Java 21 based on OS
install_java() {
    echo "Checking for Java installation..."
    
    if command_exists java; then
        # Get full version string first
        JAVA_FULL_VERSION=$(java -version 2>&1 | head -1)
        echo "Found Java: $JAVA_FULL_VERSION"
        
        # Extract the version number
        if [[ $JAVA_FULL_VERSION == *"version \""* ]]; then
            # Standard format: version "x.y.z"
            JAVA_VERSION=$(echo "$JAVA_FULL_VERSION" | awk -F'"' '{print $2}' | cut -d'.' -f1)
            
            # Handle legacy Java versions (1.8 = Java 8)
            if [[ "$JAVA_VERSION" == "1" ]]; then
                JAVA_VERSION=$(echo "$JAVA_FULL_VERSION" | awk -F'"' '{print $2}' | cut -d'.' -f2)
            fi
        else
            # Some Java implementations have different output format
            JAVA_VERSION=$(echo "$JAVA_FULL_VERSION" | grep -o '[0-9]\+' | head -1)
        fi
        
        echo "Detected Java version: $JAVA_VERSION"
        
        # Version check - we'll accept Java 11 or higher (for broader compatibility)
        if [[ "$JAVA_VERSION" -ge 11 ]]; then
            echo "Java $JAVA_VERSION is already installed and compatible with Kafka 3.7.1."
            echo "Note: Java 11 or higher is sufficient, though Java 21 is recommended."
            return 0
        else
            echo "Java is installed but version ($JAVA_VERSION) is older than 11."
            echo "Kafka 3.7.1 requires Java 11 or higher."
            
            # Ask if user wants to continue with existing Java or install new one
            read -p "Do you want to continue with the existing Java installation? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Continuing with existing Java $JAVA_VERSION."
                return 0
            else
                echo "Will attempt to install Java 21..."
            fi
        fi
    fi
    
    echo "Installing Java 21..."
    
    case "$OS_TYPE" in
        macos)
            if ! command_exists brew; then
                echo "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install openjdk@21
            
            # Add Java to PATH if not already
            if ! grep -q "openjdk@21/bin" ~/.zshrc 2>/dev/null && ! grep -q "openjdk@21/bin" ~/.bash_profile 2>/dev/null; then
                echo 'export PATH="/usr/local/opt/openjdk@21/bin:$PATH"' >> ~/.zshrc
                echo 'export PATH="/usr/local/opt/openjdk@21/bin:$PATH"' >> ~/.bash_profile
                echo "Added Java to PATH"
            fi
            
            # Create a symbolic link for system Java wrappers
            if ! [[ -L "/Library/Java/JavaVirtualMachines/openjdk-21.jdk" ]]; then
                sudo ln -sfn /usr/local/opt/openjdk@21/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-21.jdk
                echo "Set up system Java wrappers"
            fi
            ;;
            
        debian)
            sudo apt update
            sudo apt install -y openjdk-21-jre-headless
            ;;
            
        redhat)
            if command_exists dnf; then
                sudo dnf install -y java-21-openjdk
            else
                sudo yum install -y java-21-openjdk
            fi
            ;;
            
        arch)
            sudo pacman -Sy jdk-openjdk
            ;;
            
        *)
            echo "Unable to install Java automatically on this OS. Please install Java 21 manually."
            exit 1
            ;;
    esac
    
    # Verify Java installation
    if command_exists java; then
        echo "Java has been installed successfully."
    else
        echo "Java installation failed. Please install Java 21 manually."
        exit 1
    fi
}

# Install wget based on OS
install_wget() {
    if command_exists wget; then
        echo "wget is already installed."
        return 0
    fi
    
    echo "Installing wget..."
    
    case "$OS_TYPE" in
        macos)
            brew install wget
            ;;
            
        debian)
            sudo apt install -y wget
            ;;
            
        redhat)
            if command_exists dnf; then
                sudo dnf install -y wget
            else
                sudo yum install -y wget
            fi
            ;;
            
        arch)
            sudo pacman -Sy wget
            ;;
            
        *)
            echo "Unable to install wget automatically on this OS. Please install wget manually."
            exit 1
            ;;
    esac
    
    # Verify wget installation
    if command_exists wget; then
        echo "wget has been installed successfully."
    else
        echo "wget installation failed. Please install wget manually."
        exit 1
    fi
}

# Install Java
install_java

# Install wget
install_wget

# Download and extract Kafka
KAFKA_VERSION="3.9.0"
KAFKA_DIR="kafka_2.13-$KAFKA_VERSION"
KAFKA_TGZ="$KAFKA_DIR.tgz"

if [ ! -d "$KAFKA_DIR" ]; then
    echo "Downloading Kafka $KAFKA_VERSION..."
    wget "https://downloads.apache.org/kafka/$KAFKA_VERSION/$KAFKA_TGZ"
    echo "Extracting Kafka $KAFKA_VERSION..."
    tar -xzf "$KAFKA_TGZ"
    echo "Cleaning up the archive file..."
    rm "$KAFKA_TGZ"
else
    echo "Kafka $KAFKA_VERSION is already downloaded."
fi

# Navigate to the Kafka directory
cd "$KAFKA_DIR" || exit

echo "Kafka installation completed successfully!"
#echo "To start Kafka, run these commands in separate terminal windows:"
#echo "1. Start Zookeeper: ./bin/zookeeper-server-start.sh config/zookeeper.properties"
#echo "2. Start Kafka: ./bin/kafka-server-start.sh config/server.properties"