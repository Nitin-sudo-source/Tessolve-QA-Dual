import { LightningElement, api, track } from 'lwc';

const DEBOUNCE_DELAY = 300;
const ITEM_HEIGHT = 36;
const BUFFER = 5;
export default class SearchableCombobox extends LightningElement {

        @api placeholder = 'Search...';
    @api disabled = false;

    _options = [];

    @api
    set options(data) {
        this._options = (data || []).map(opt => ({
            ...opt,
            searchLabel: opt.label.toLowerCase()
        }));

        this.filteredOptions = this._options;
        this.totalHeight = this._options.length * ITEM_HEIGHT;

        this.updateVisibleItems(0);

        // 🔥 Auto-select if only 1 option
        if (this._options.length === 1) {
            this.selectOption(this._options[0]);
        }
    }

    get options() {
        return this._options;
    }

    @api value = '';

    @track filteredOptions = [];
    @track visibleOptions = [];

    isOpen = false;
    isLoading = false;

    debounceTimeout;
    highlightIndex = -1;

    totalHeight = 0;
    startIndex = 0;

    // ===== INPUT =====
    handleInput(event) {
        const searchKey = event.target.value;
        this.value = searchKey;

        clearTimeout(this.debounceTimeout);

        this.debounceTimeout = setTimeout(() => {
            this.isLoading = true;

            this.dispatchEvent(new CustomEvent('search', {
                detail: { searchKey }
            }));
        }, DEBOUNCE_DELAY);
    }

    // ===== RECEIVE DATA =====
    @api
    stopLoading() {
        this.isLoading = false;
    }

    // ===== VIRTUAL SCROLL =====
    handleScroll(event) {
        this.updateVisibleItems(event.target.scrollTop);
    }

    updateVisibleItems(scrollTop) {
        const visibleCount = Math.ceil(200 / ITEM_HEIGHT);

        this.startIndex = Math.max(0, Math.floor(scrollTop / ITEM_HEIGHT) - BUFFER);

        const endIndex = Math.min(
            this.filteredOptions.length,
            this.startIndex + visibleCount + BUFFER * 2
        );

        this.visibleOptions = this.filteredOptions.slice(this.startIndex, endIndex);
    }

    get spacerStyle() {
        return `height:${this.totalHeight}px; position:relative;`;
    }

    get translateStyle() {
        return `transform: translateY(${this.startIndex * ITEM_HEIGHT}px); position:absolute; width:100%;`;
    }

    // ===== KEYBOARD NAV =====
    handleKeyDown(event) {
        if (!this.isOpen) return;

        if (event.key === 'ArrowDown') {
            event.preventDefault();
            this.highlightIndex = Math.min(this.highlightIndex + 1, this.filteredOptions.length - 1);
        }

        if (event.key === 'ArrowUp') {
            event.preventDefault();
            this.highlightIndex = Math.max(this.highlightIndex - 1, 0);
        }

        if (event.key === 'Enter' && this.highlightIndex >= 0) {
            this.selectOption(this.filteredOptions[this.highlightIndex]);
        }
    }

    // ===== SELECT =====
    handleSelect(event) {
        const value = event.currentTarget.dataset.value;
        const label = event.currentTarget.dataset.label;

        this.selectOption({ value, label });
    }

    selectOption(option) {
        this.value = option.label;
        this.isOpen = false;

        this.dispatchEvent(new CustomEvent('change', {
            detail: { value: option.value }
        }));
    }

    // ===== UI =====
    handleFocus() {
        this.isOpen = true;
    }

    handleBlur() {
        setTimeout(() => {
            this.isOpen = false;
        }, 200);
    }

    get hasResults() {
        return this.filteredOptions.length > 0;
    }
}