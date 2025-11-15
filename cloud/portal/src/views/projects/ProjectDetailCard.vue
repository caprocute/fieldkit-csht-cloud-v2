<template>
    <div class="project-detail-card" :class="{ 'mobile-expanded': showLinksOnMobile }" @click="showLinksOnMobile = !showLinksOnMobile">
        <div class="photo-container">
            <ProjectPhoto :project="project" :image-size="150" />
        </div>
        <div class="detail-container">
            <component
                v-bind:is="partnerCustomization.components.project"
                :project="project"
                :showLinksOnMobile="showLinksOnMobile"
            ></component>
        </div>
    </div>
</template>

<script lang="ts">
import Vue, { PropType } from "vue";
import { getPartnerCustomizationWithDefault, isCustomisationEnabled, PartnerCustomization } from "@/views/shared/partners";
import { Project } from "@/api/api";
import ProjectPhoto from "@/views/shared/ProjectPhoto.vue";

export default Vue.extend({
    name: "ProjectDetailCard",
    components: {
        ProjectPhoto,
    },
    props: {
        project: {
            type: Object as PropType<Project>,
            required: true,
        },
    },
    data(): {
        showLinksOnMobile: boolean;
        isMobileView: boolean;
    } {
        return {
            showLinksOnMobile: false,
            isMobileView: window.screen.availWidth < 768,
        };
    },
    computed: {
        partnerCustomization(): PartnerCustomization {
            return getPartnerCustomizationWithDefault();
        },
        isPartnerCustomisationEnabled(): boolean {
            return isCustomisationEnabled();
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/project-detail-card";
</style>
