# claude-code.nvim Makefile
# Symlinks configuration files to ~/.claude for development

CLAUDE_DIR := $(HOME)/.claude
HOOKS_DIR := $(CLAUDE_DIR)/hooks
CONFIG_DIR := $(shell pwd)/config

.PHONY: install uninstall status

install: ## Symlink hooks and statusline-bridge to ~/.claude
	@echo "Installing claude-code.nvim configuration..."
	@mkdir -p $(HOOKS_DIR)

	@# Ensure source scripts are executable
	@chmod +x $(CONFIG_DIR)/hooks/*.sh $(CONFIG_DIR)/statusline-bridge.sh

	@# Symlink hooks
	@for hook in $(CONFIG_DIR)/hooks/*.sh; do \
		name=$$(basename $$hook); \
		if [ -L "$(HOOKS_DIR)/$$name" ]; then \
			rm "$(HOOKS_DIR)/$$name"; \
		elif [ -f "$(HOOKS_DIR)/$$name" ]; then \
			echo "Backing up existing $$name to $$name.bak"; \
			mv "$(HOOKS_DIR)/$$name" "$(HOOKS_DIR)/$$name.bak"; \
		fi; \
		ln -s "$$hook" "$(HOOKS_DIR)/$$name"; \
		echo "  Linked: $$name"; \
	done

	@# Symlink statusline-bridge
	@if [ -L "$(CLAUDE_DIR)/statusline-bridge.sh" ]; then \
		rm "$(CLAUDE_DIR)/statusline-bridge.sh"; \
	elif [ -f "$(CLAUDE_DIR)/statusline-bridge.sh" ]; then \
		echo "Backing up existing statusline-bridge.sh"; \
		mv "$(CLAUDE_DIR)/statusline-bridge.sh" "$(CLAUDE_DIR)/statusline-bridge.sh.bak"; \
	fi
	@ln -s "$(CONFIG_DIR)/statusline-bridge.sh" "$(CLAUDE_DIR)/statusline-bridge.sh"
	@echo "  Linked: statusline-bridge.sh"

	@# Merge settings.json
	@echo ""
	@echo "Merging settings.json..."
	@if [ ! -f "$(CLAUDE_DIR)/settings.json" ]; then \
		cp "$(CONFIG_DIR)/settings.json" "$(CLAUDE_DIR)/settings.json"; \
		echo "  Created: settings.json"; \
	elif command -v jq >/dev/null 2>&1; then \
		cp "$(CLAUDE_DIR)/settings.json" "$(CLAUDE_DIR)/settings.json.bak"; \
		jq -s '.[0] * .[1]' "$(CLAUDE_DIR)/settings.json.bak" "$(CONFIG_DIR)/settings.json" > "$(CLAUDE_DIR)/settings.json"; \
		echo "  Merged: settings.json (backup: settings.json.bak)"; \
	else \
		echo "  Warning: jq not found, cannot merge settings.json"; \
		echo "  Please manually merge $(CONFIG_DIR)/settings.json"; \
	fi

	@echo ""
	@echo "Installation complete!"

uninstall: ## Remove symlinks from ~/.claude
	@echo "Removing claude-code.nvim symlinks..."
	@for hook in $(CONFIG_DIR)/hooks/*.sh; do \
		name=$$(basename $$hook); \
		if [ -L "$(HOOKS_DIR)/$$name" ]; then \
			rm "$(HOOKS_DIR)/$$name"; \
			echo "  Removed: $$name"; \
		fi; \
	done
	@if [ -L "$(CLAUDE_DIR)/statusline-bridge.sh" ]; then \
		rm "$(CLAUDE_DIR)/statusline-bridge.sh"; \
		echo "  Removed: statusline-bridge.sh"; \
	fi
	@echo "Done."

status: ## Show current symlink status
	@echo "Hook symlink status:"
	@for hook in $(CONFIG_DIR)/hooks/*.sh; do \
		name=$$(basename $$hook); \
		if [ -L "$(HOOKS_DIR)/$$name" ]; then \
			target=$$(readlink "$(HOOKS_DIR)/$$name"); \
			echo "  ✓ $$name -> $$target"; \
		elif [ -f "$(HOOKS_DIR)/$$name" ]; then \
			echo "  ✗ $$name (regular file, not symlink)"; \
		else \
			echo "  - $$name (not installed)"; \
		fi; \
	done
	@echo ""
	@echo "Statusline bridge:"
	@if [ -L "$(CLAUDE_DIR)/statusline-bridge.sh" ]; then \
		target=$$(readlink "$(CLAUDE_DIR)/statusline-bridge.sh"); \
		echo "  ✓ statusline-bridge.sh -> $$target"; \
	elif [ -f "$(CLAUDE_DIR)/statusline-bridge.sh" ]; then \
		echo "  ✗ statusline-bridge.sh (regular file, not symlink)"; \
	else \
		echo "  - statusline-bridge.sh (not installed)"; \
	fi

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
