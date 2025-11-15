<template>
    <StandardLayout>
        <button v-on:click="onToggle">{{ $t("admin.playground.modal") }}</button>
        <StationPickerModal :stations="stations" @close="onToggle" v-if="modalOpen" />

        <div>
            <UserPicker @picked="onUser" />
        </div>
    </StandardLayout>
</template>

<script lang="ts">
import Vue from "vue";
import StandardLayout from "../StandardLayout.vue";
import CommonComponents from "@/views/shared";

import StationPickerModal from "@/views/shared/StationPickerModal.vue";
import UserPicker from "./UserPicker.vue";

import { mapState } from "vuex";
import { GlobalState } from "@/store/modules/global";

export default Vue.extend({
    name: "Playground",
    components: {
        StandardLayout,
        ...CommonComponents,
        StationPickerModal,
        UserPicker,
    },
    props: {},
    data: () => {
        return {
            modalOpen: false,
        };
    },
    computed: {
        ...mapState({
            stations: (s: GlobalState) => s.stations.user.stations,
        }),
    },
    methods: {
        onToggle(): void {
            this.modalOpen = !this.modalOpen;
        },
        onUser(user: unknown): void {
            console.log(`user-picked: ${user}`);
        },
    },
});
</script>

<style scoped>
.container {
    display: flex;
    flex-direction: column;
    padding: 20px;
    max-width: 900px;
}
</style>
