#!/bin/bash

# Morsyxbt: Boundless Guild Quest Script
# Color output setup
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                🛡️ SMorsyxbt GUILD RITUAL              ║"
echo "║         Auto Quest for Boundless | Dev + Prover         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

set -e

get_user_inputs() {
    echo -e "${YELLOW}Enter the required info for setup:${NC}"
    echo ""

    read -p "Enter your Alchemy Base Mainnet RPC URL: " ALCHEMY_RPC
    if [[ -z "$ALCHEMY_RPC" ]]; then
        echo -e "${RED}❌ RPC URL cannot be empty!${NC}"
        exit 1
    fi

    echo ""
    echo -e "${YELLOW}For safety, only use a fresh wallet's private key!${NC}"
    read -s -p "Enter your wallet private key (it will be hidden): " PRIVATE_KEY
    echo ""
    if [[ -z "$PRIVATE_KEY" ]]; then
        echo -e "${RED}❌ Private key cannot be empty!${NC}"
        exit 1
    fi

    echo ""
    echo -e "${BLUE}Which role do you want to activate?${NC}"
    echo "1) Prover (Requires 0.01 USDC)"
    echo "2) Dev (Requires 0.000001 ETH)"
    echo "3) Both (0.01 USDC + 0.000001 ETH)"
    read -p "Select role (1, 2 or 3): " ROLE_CHOICE

    if [[ "$ROLE_CHOICE" == "1" ]]; then
        ROLE="prover"
        read -p "Enter USDC stake amount (default: 0.01): " STAKE_AMOUNT
        STAKE_AMOUNT=${STAKE_AMOUNT:-0.01}
    elif [[ "$ROLE_CHOICE" == "2" ]]; then
        ROLE="dev"
        read -p "Enter ETH deposit amount (default: 0.000001): " DEPOSIT_AMOUNT
        DEPOSIT_AMOUNT=${DEPOSIT_AMOUNT:-0.000001}
    elif [[ "$ROLE_CHOICE" == "3" ]]; then
        ROLE="both"
        read -p "Enter USDC stake amount (default: 0.01): " STAKE_AMOUNT
        STAKE_AMOUNT=${STAKE_AMOUNT:-0.01}
        read -p "Enter ETH deposit amount (default: 0.000001): " DEPOSIT_AMOUNT
        DEPOSIT_AMOUNT=${DEPOSIT_AMOUNT:-0.000001}
    else
        echo -e "${RED}❌ Invalid selection!${NC}"
        exit 1
    fi
}

update_system() {
    echo -e "${BLUE}Updating system...${NC}"
    sudo apt update -y
    sudo apt install -y curl git build-essential cmake protobuf-compiler
    echo -e "${GREEN}System updated${NC}"
}

create_screen() {
    echo -e "${BLUE}Creating screen session...${NC}"
    if screen -list | grep -q "boundless"; then
        echo -e "${YELLOW}Screen session already exists${NC}"
    else
        screen -dmS boundless
        echo -e "${GREEN}Screen session created${NC}"
    fi
}

clone_repo() {
    echo -e "${BLUE}Cloning Boundless repo...${NC}"
    if [ -d "boundless" ]; then
        echo -e "${YELLOW}Repo already exists, pulling updates...${NC}"
        cd boundless
        git pull
        cd ..
    else
        git clone https://github.com/boundless-xyz/boundless
    fi
    cd boundless
    echo -e "${GREEN}Repo ready${NC}"
}

install_rust() {
    echo -e "${BLUE}Installing Rust...${NC}"
    if command -v rustc &> /dev/null; then
        echo -e "${YELLOW}Rust already installed${NC}"
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
        echo -e "${GREEN}Rust installed${NC}"
    fi
}

install_risc_zero() {
    echo -e "${BLUE}Installing RISC Zero...${NC}"
    curl -L https://risczero.com/install | bash
    source ~/.bashrc
    export PATH="$HOME/.risc0/bin:$PATH"
    rzup install
    echo -e "${GREEN}RISC Zero installed${NC}"
}

install_bento() {
    echo -e "${BLUE}Installing Bento Client...${NC}"
    source $HOME/.cargo/env
    cargo install --git https://github.com/risc0/risc0 bento-client --bin bento_cli
    echo -e "${GREEN}Bento Client installed${NC}"
}

update_path() {
    echo -e "${BLUE}Updating PATH...${NC}"
    export PATH="$HOME/.cargo/bin:$PATH"
    if ! grep -q 'export PATH="$HOME/.cargo/bin:$PATH"' ~/.bashrc; then
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
    fi
    source ~/.bashrc
    echo -e "${GREEN}PATH updated${NC}"
}

install_cli() {
    echo -e "${BLUE}Installing Boundless CLI...${NC}"
    source $HOME/.cargo/env
    cargo install --locked boundless-cli
    echo -e "${GREEN}Boundless CLI installed${NC}"
}

create_env() {
    echo -e "${BLUE}Creating environment file...${NC}"
    cat > .env.base << EOF
export VERIFIER_ADDRESS=0x0b144e07a0826182b6b59788c34b32bfa86fb711
export BOUNDLESS_MARKET_ADDRESS=0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8
export SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
export ORDER_STREAM_URL="https://base-mainnet.beboundless.xyz"
export ETH_RPC_URL="$ALCHEMY_RPC"
export PRIVATE_KEY="$PRIVATE_KEY"
EOF
    source .env.base
    echo -e "${GREEN}Environment file created${NC}"
}

check_balance() {
    echo -e "${BLUE}💰 Checking wallet balance...${NC}"
    echo -e "${YELLOW}⚠️  Make sure your wallet has the required balance:${NC}"

    if [[ "$ROLE" == "prover" ]]; then
        echo -e "${YELLOW}   - ${STAKE_AMOUNT} USDC${NC}"
        echo -e "${YELLOW}   - Some ETH for gas (~$2-3)${NC}"
    elif [[ "$ROLE" == "dev" ]]; then
        echo -e "${YELLOW}   - ${DEPOSIT_AMOUNT} ETH${NC}"
        echo -e "${YELLOW}   - Some ETH for gas${NC}"
    else
        echo -e "${YELLOW}   - ${STAKE_AMOUNT} USDC${NC}"
        echo -e "${YELLOW}   - ${DEPOSIT_AMOUNT} ETH${NC}"
        echo -e "${YELLOW}   - Some ETH for gas (~$5-6)${NC}"
    fi

    echo ""
    read -p "Is your balance sufficient? (y/n): " BALANCE_OK
    if [[ "$BALANCE_OK" != "y" && "$BALANCE_OK" != "Y" ]]; then
        echo -e "${RED}❌ Please fund your wallet before continuing${NC}"
        exit 1
    fi
}

execute_transaction() {
    echo -e "${BLUE}Executing transaction(s)...${NC}"

    if [[ "$ROLE" == "prover" ]]; then
        echo -e "${YELLOW}Staking ${STAKE_AMOUNT} USDC...${NC}"
        boundless \
          --rpc-url "$ETH_RPC_URL" \
          --private-key "$PRIVATE_KEY" \
          --boundless-market-address 0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8 \
          --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 \
          --verifier-router-address 0x0b144e07a0826182b6b59788c34b32bfa86fb711 \
          --order-stream-url "https://base-mainnet.beboundless.xyz" \
          --chain-id 8453 \
          account deposit-stake $STAKE_AMOUNT

    elif [[ "$ROLE" == "dev" ]]; then
        echo -e "${YELLOW}Depositing ${DEPOSIT_AMOUNT} ETH...${NC}"
        boundless \
          --rpc-url "$ETH_RPC_URL" \
          --private-key "$PRIVATE_KEY" \
          --boundless-market-address 0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8 \
          --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 \
          --verifier-router-address 0x0b144e07a0826182b6b59788c34b32bfa86fb711 \
          --order-stream-url "https://base-mainnet.beboundless.xyz" \
          --chain-id 8453 \
          account deposit $DEPOSIT_AMOUNT

    else
        echo -e "${YELLOW}Staking ${STAKE_AMOUNT} USDC...${NC}"
        boundless \
          --rpc-url "$ETH_RPC_URL" \
          --private-key "$PRIVATE_KEY" \
          --boundless-market-address 0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8 \
          --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 \
          --verifier-router-address 0x0b144e07a0826182b6b59788c34b32bfa86fb711 \
          --order-stream-url "https://base-mainnet.beboundless.xyz" \
          --chain-id 8453 \
          account deposit-stake $STAKE_AMOUNT

        echo -e "${YELLOW}Depositing ${DEPOSIT_AMOUNT} ETH...${NC}"
        sleep 2
        boundless \
          --rpc-url "$ETH_RPC_URL" \
          --private-key "$PRIVATE_KEY" \
          --boundless-market-address 0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8 \
          --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 \
          --verifier-router-address 0x0b144e07a0826182b6b59788c34b32bfa86fb711 \
          --order-stream-url "https://base-mainnet.beboundless.xyz" \
          --chain-id 8453 \
          account deposit $DEPOSIT_AMOUNT
    fi

    echo -e "${GREEN}✅ Transaction(s) completed${NC}"
}

show_completion() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║               ✅ GUILD QUEST COMPLETED!                  ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${BLUE}Summary:${NC}"
    if [[ "$ROLE" == "prover" ]]; then
        echo -e "${GREEN}   ✅ Prover: ${STAKE_AMOUNT} USDC staked${NC}"
    elif [[ "$ROLE" == "dev" ]]; then
        echo -e "${GREEN}   ✅ Dev: ${DEPOSIT_AMOUNT} ETH deposited${NC}"
    else
        echo -e "${GREEN}   ✅ Prover: ${STAKE_AMOUNT} USDC staked${NC}"
        echo -e "${GREEN}   ✅ Dev: ${DEPOSIT_AMOUNT} ETH deposited${NC}"
    fi
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Complete your Boundless Guild tasks:"
    echo "   https://guild.xyz/boundless-xyz"
    echo "2. Join Boundless Discord & get roles"
    echo "3. Complete Discord quests"
    echo ""
    echo -e "${GREEN}🎉 Welcome to the Boundless Network!${NC}"
}

main() {
    echo -e "${BLUE}🚀 Starting setup...${NC}"
    echo ""

    get_user_inputs
    echo ""
    echo -e "${BLUE}Setup Summary:${NC}"
    echo -e "${YELLOW}   RPC URL: ${ALCHEMY_RPC}${NC}"

    if [[ "$ROLE" == "prover" ]]; then
        echo -e "${YELLOW}   Role: Prover${NC}"
        echo -e "${YELLOW}   Stake: ${STAKE_AMOUNT} USDC${NC}"
    elif [[ "$ROLE" == "dev" ]]; then
        echo -e "${YELLOW}   Role: Dev${NC}"
        echo -e "${YELLOW}   Deposit: ${DEPOSIT_AMOUNT} ETH${NC}"
    else
        echo -e "${YELLOW}   Role: Both (Prover + Dev)${NC}"
        echo -e "${YELLOW}   Stake: ${STAKE_AMOUNT} USDC${NC}"
        echo -e "${YELLOW}   Deposit: ${DEPOSIT_AMOUNT} ETH${NC}"
    fi

    echo ""
    read -p "Continue with installation? (y/n): " CONTINUE
    if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
        echo -e "${YELLOW}❌ Setup cancelled${NC}"
        exit 0
    fi

    echo ""
    update_system
    create_screen
    clone_repo
    install_rust
    install_risc_zero
    install_bento
    update_path
    install_cli
    create_env
    check_balance
    execute_transaction
    show_completion
}

trap 'echo -e "${RED}❌ An error occurred. Exiting...${NC}"; exit 1' ERR

main
