<template>
    <div class="language-selector" :class="{ opened: isLangListVisible }">
        <div class="lang-toggle" @click="toggleLangList()" @mouseover="onMouseOver()" @mosueout="onMouseOut()">
            <i class="icon icon-globe"></i>
            <span class="triangle"></span>
            <span class="toggle-text">{{ $t("languageSelector.toggleText") }}</span>
        </div>
        <ul v-if="showLangList" class="language-list">
            <li @click="changeLang(Locales.enUS)">{{ $t("languageSelector.english") }}</li>
            <li @click="changeLang(Locales.esEs)">{{ $t("languageSelector.spanish") }}</li>
        </ul>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import { ActionTypes } from "@/store";
import { updateDocumentTitle } from "@/router";
import moment from "moment";
import { isSmallScreen } from "@/utilities";

export enum Locales {
    enUS = "en-US",
    esEs = "es-ES",
}

export default Vue.extend({
    name: "LanguageSelector",
    data() {
        return {
            Locales: Locales,
            isLangListVisible: false,
        };
    },
    computed: {
        showLangList(): boolean {
            if (!isSmallScreen()) {
                return true;
            }
            return this.isLangListVisible;
        },
    },
    methods: {
        changeLang(locale: Locales) {
            this.$i18n.locale = locale;
            localStorage.setItem("locale", locale);
            this.$store.dispatch(ActionTypes.REFRESH_WORKSPACE);
            updateDocumentTitle();
            moment.locale(locale);
            this.$root.$emit("language-changed");
        },
        onMouseOver(): void {
            if (!isSmallScreen()) {
                this.isLangListVisible = true;
            }
        },
        onMouseOut(): void {
            if (!isSmallScreen()) {
                this.isLangListVisible = false;
            }
        },
        toggleLangList(): void {
            if (isSmallScreen()) {
                this.isLangListVisible = !this.isLangListVisible;
            }
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/mixins";
@use "src/scss/variables";

.toggle-text {
    display: none;
    text-transform: uppercase;
    font-size: 11px;
    font-weight: 900;
    margin-right: auto;
    margin-left: auto;
    user-select: none;

    @include mixins.bp-down(variables.$sm) {
        display: block;
    }
}

.language-selector {
    margin-right: 20px;
    margin-top: -3px;
    padding: 10px;
    position: relative;
    height: 100%;
    display: flex;
    align-items: center;
    box-sizing: border-box;

    @include mixins.bp-down(variables.$sm) {
        margin-right: 5px;
        margin-bottom: 20px;
        flex-direction: column;
        height: auto;
        padding: 7px 19px 0;
        border-bottom: solid 1px #f4f5f7;
    }

    .triangle {
        opacity: 0;
        visibility: hidden;
        bottom: -3px;
    }

    @include mixins.attention() {
        .language-list,
        .triangle {
            visibility: visible;
            opacity: 1;
        }
    }

    &.opened {
        &:after {
            transform: rotate(180deg) translateY(50%);
        }
    }
}

.language-list {
    position: absolute;
    right: -10px;
    top: 67px;
    box-shadow: 2px 2.3px 4px 1px rgba(0, 0, 0, 0.04);
    border: solid 1px #d8dce0;
    background-color: #fff;
    min-width: 100px;
    opacity: 0;
    visibility: hidden;
    padding-top: 10px;

    @include mixins.bp-down(variables.$sm) {
        position: unset;
        visibility: visible;
        opacity: 1;
        width: calc(100% + 30px + 12px);
        margin-left: 6px;
        padding-bottom: 10px;
        background: #f4f5f7;
        border: none;
        box-shadow: none;
    }

    li {
        padding: 6px 12px;
        text-align: left;
        cursor: pointer;
        transition: background-color 0.5ms;

        &.active,
        &:hover {
            background-color: #f4f5f7;
        }

        @include mixins.bp-down(variables.$sm) {
            font-size: 12px;
            font-weight: 900;
            text-align: center;
        }
    }
}

.icon-globe {
    font-size: 16px;

    @include mixins.bp-down(variables.$sm) {
        margin-top: -3px;
    }
}

.lang-toggle {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    height: 40px;

    &:after {
        content: "";
        background: url("../../assets/icon-chevron-dropdown.svg") no-repeat center center;
        background-size: 12px;
        width: 10px;
        height: 10px;
        transition: all 0.33s;
        transform: translateY(-50%);
        cursor: pointer;
        @include mixins.position(absolute, 50% null null calc(100% - 5px));

        @include mixins.bp-down(variables.$lg) {
            top: 26px;
            right: 15px;
            left: unset;
        }
    }

    @include mixins.bp-up(variables.$sm) {
        &:hover {
            &:after {
                transform: rotate(180deg) translateY(50%);
            }
        }
    }
}
</style>
