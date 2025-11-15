<template>
    <div class="sps" v-bind:class="{ selected: selected }">
        <div class="standard" v-on:click="onClicked">
            <div class="name">{{ station.name }}</div>
            <div class="location" v-if="!narrow">{{ location }}</div>
            <div class="status">{{ status }}</div>
            <div class="seen" v-if="!narrow">{{ station.updatedAt | prettyDate }}</div>
        </div>
        <slot></slot>
    </div>
</template>

<script lang="ts">
import _ from "lodash";
import Vue from "vue";

export default Vue.extend({
    name: "StationPickerStation",
    props: {
        station: {
            type: Object,
            required: true,
        },
        selected: {
            type: Boolean,
            default: false,
        },
        narrow: {
            type: Boolean,
            default: false,
        },
    },
    computed: {
        location(this: any) {
            const gps = [this.station.location?.latitude, this.station.location?.longitude]
                .filter((v) => v)
                .map((v) => v.toFixed(3))
                .join(", ");
            const locations = [gps, "Unknown"];
            return _(locations).compact().first();
        },
        status(this: any) {
            if (this.station.deployedAt) {
                return this.$t("station.deployed");
            }
            return this.$t("station.readyToDeploy");
        },
    },
    methods: {
        onClicked() {
            this.$emit("selected");
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/mixins";
@use "src/scss/variables";

.sps {
    display: flex;
    border: 1px solid var(--color-border);
    padding: 1px;
    border-radius: 3px;
    position: relative;
    margin: 0 8px 23px 8px;
    flex: 0 0 calc(33% - 16px);
    box-sizing: border-box;
    cursor: pointer;

    @include mixins.bp-down(variables.$sm) {
        flex: 0 0 calc(50% - 18px);
    }

    @include mixins.bp-down(variables.$xs) {
        flex: 0 0 100%;
        margin: 0 0 10px;
    }
}
.sps.selected {
    border: 2px solid #1b80c9;
    padding: 0;

    &:after {
        @include mixins.position(absolute, -6px -6px null null);
        content: "";
        background: url("../../assets/icon-success-blue.svg") no-repeat center center;
        background-size: contain;
        width: 19px;
        height: 19px;
    }
}
.sps .standard {
    text-align: left;
    display: flex;
    flex-direction: column;
    padding: 12px 16px;
    width: 100%;
}
.sps .name {
    font-size: 16px;
}
.sps .location {
    font-size: 14px;
}
.sps .status {
    margin-top: 2px;
    font-size: 12px;
    color: #6a6d71;
}
.sps .seen {
    font-size: 12px;
    color: #6a6d71;
}
</style>
