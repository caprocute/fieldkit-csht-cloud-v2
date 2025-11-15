<template>
    <div class="row general-row" ref="summaryGeneralRow" v-if="station">
        <div class="image-container">
            <StationPhoto :station="station" />
        </div>
        <div class="station-details">
            <div class="station-name">
                {{ station.name }}
                <slot name="top-right-actions"></slot>
            </div>

            <template v-if="isCustomisationEnabled()">
                <div class="row where-row">
                    <div v-if="neighborhood || borough" class="location-container">
                        <i class="icon icon-location" />
                        <template v-if="neighborhood">{{ neighborhood }}</template>
                        <template v-if="neighborhood && borough">{{ ", " }}</template>
                        <template v-if="borough">{{ borough }}</template>
                    </div>
                    <div v-if="deploymentDate || deployedBy" class="location-container">
                        <i class="icon icon-calendar" />
                        <template v-if="deploymentDate">{{ $t("station.deployedOn") }} {{ deploymentDate }}</template>
                        <template v-if="deployedBy">{{ " " }}{{ $t("station.by") }} {{ deployedBy }}</template>
                    </div>
                </div>
            </template>

            <template v-else>
                <div
                    class="row where-row"
                    v-if="stationLocationName || station.placeNameNative || station.placeNameOther || station.placeNameNative"
                >
                    <div class="location-container">
                        <div v-if="stationLocationName || station.placeNameOther">
                            <i class="icon icon-location" />
                            <template>
                                {{ stationLocationName ? stationLocationName : station.placeNameOther }}
                            </template>
                        </div>
                        <div v-if="station.placeNameNative">
                            <i class="icon icon-location" />
                            <span>
                                {{ $t("station.nativeLands") }}
                                <span class="bold">{{ station.placeNameNative }}</span>
                            </span>
                        </div>
                    </div>
                </div>
            </template>

            <div v-if="!isMobileView && !isCustomisationEnabled()" class="station-modules">
                <ModuleIcon
                    v-for="(module, index) in station.modules"
                    v-bind:key="index"
                    :module="module"
                />
            </div>

            <slot name="extra-detail"></slot>
        </div>

        <div v-if="isMobileView && !isCustomisationEnabled()" class="station-modules">
            <ModuleIcon
                v-for="(module, index) in station.modules"
                v-bind:key="index"
                :module="module"
            />
        </div>
    </div>
</template>

<script lang="ts">
import Vue, { PropType } from "vue";
import CommonComponents from "@/views/shared";
import ModuleIcon from "@/views/shared/ModuleIcon.vue";
import * as utils from "@/utilities";
import { DisplayStation } from "@/store";
import { getPartnerCustomizationWithDefault, isCustomisationEnabled, PartnerCustomization } from "@/views/shared/partners";

export default Vue.extend({
    name: "StationSummaryContent",
    components: {
        ...CommonComponents,
        ModuleIcon,
    },
    data: () => {
        return {
            isMobileView: window.screen.availWidth < 500,
        };
    },
    props: {
        station: {
            type: Object as PropType<DisplayStation>,
            default: null,
        },
    },
    computed: {
        stationLocationName(): string {
            return this.partnerCustomization().stationLocationName(this.station);
        },
        // TODO: refactor using functions from partner.ts
        neighborhood(): string {
            return this.getAttributeValue("Neighborhood");
        },
        borough(): string {
            return this.getAttributeValue("Borough");
        },
        deploymentDate(): string {
            return this.getAttributeValue("Deployment Date");
        },
        deployedBy(): string {
            return this.getAttributeValue("Deployed By");
        },
    },
    methods: {
        getBatteryIcon() {
            return this.$loadAsset(utils.getBatteryIcon(this.station.battery));
        },
        partnerCustomization(): PartnerCustomization {
            return getPartnerCustomizationWithDefault();
        },
        isCustomisationEnabled(): boolean {
            return isCustomisationEnabled();
        },
        getAttributeValue(attrName: string): any {
            if (this.station) {
                const value = this.station.attributes.find((attr) => attr.name === attrName)?.stringValue;
                return value ? value : null;
            }
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/mixins";
@use "src/scss/variables";

.image-container {
    flex: 0 0 95px;
    height: 90px;
    text-align: center;
    display: flex;
    border-radius: 5px;
    padding: 0;
    margin-right: 14px;
    overflow: hidden;

    img {
        padding: 0;
        object-fit: cover;
    }
}

.image-container img {
    width: 100%;
    border-radius: 3px;
}

.station-name {
    font-size: 18px;
    font-family: var(--font-family-bold);
    margin-bottom: 3px;
    padding-right: 45px;
}

.station-synced {
    font-size: 14px;
}

.general-row {
    display: flex;
    flex-direction: row;
    flex-wrap: wrap;
    flex: 1;
    position: relative;
}

.station-details {
    text-align: left;
    flex: 1 0;
}

.location-container {
    display: flex;
    margin-bottom: 2px;
    font-size: 14px;

    > div {
        @include mixins.flex(flex-start);
        margin-bottom: 5px;

        &:first-of-type {
            .summary-content & {
                margin-right: 10px;
            }
        }
    }
}

.icon {
    padding-right: 5px;
    transform: translateY(2px);
}

.icon-calendar {
    font-size: 12px;
}

.station-modules {
    @include mixins.flex();
    margin-left: -2px;
    flex: 0 0 100%;

    @include mixins.bp-down(variables.$xs) {
        margin-top: 10px;
        margin-left: 0;
    }

    ::v-deep .module-icon {
        width: 24px;
        height: 24px;
        margin-right: 6px;

        @include mixins.bp-down(variables.$xs) {
            width: 18px;
            height: 18px;
            margin-right: 3px;
        }
    }

    ::v-deep .tooltip-text {
        bottom: calc(-100% - 6px);

        @include mixins.bp-down(variables.$xs) {
            bottom: calc(-100% - 3px);
        }
    }
}

.coordinates-row {
    display: flex;
    flex-direction: row;
    justify-content: space-between;
    margin-top: 7px;
}

.where-row {
    display: flex;
    flex-direction: column;
    text-align: left;
    font-size: 14px;
    padding-bottom: 5px;
    margin-top: 5px;
    color: var(--color-dark);
}
</style>
