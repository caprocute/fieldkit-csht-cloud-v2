<template>
    <div class="notes-form">
        <div class="header">
            <div class="name">{{ $t("notes.title") }}</div>
            <div class="completed">{{ completed }}% {{ $t("notes.complete") }}</div>
            <div class="buttons" v-if="isAuthenticated">
                <button type="submit" :class="{ disabled: readonly }" class="button" @click="onSave" data-cy="saveNotes">
                    {{ $t("notes.btn.save") }}
                </button>
            </div>
        </div>
        <div class="site-notes">
            <form id="form">
                <NoteEditor
                    v-model="form.studyObjective"
                    :v="$v.form.studyObjective"
                    :readonly="readonly"
                    :dataCy="'studyObjectiveBody'"
                    @change="onChange('studyObjective')"
                />
                <NoteEditor
                    v-model="form.sitePurpose"
                    :v="$v.form.sitePurpose"
                    :readonly="readonly"
                    :dataCy="'sitePurposeBody'"
                    @change="onChange('sitePurpose')"
                />
                <NoteEditor
                    v-model="form.siteCriteria"
                    :v="$v.form.siteCriteria"
                    :readonly="readonly"
                    :dataCy="'siteCriteriaBody'"
                    @change="onChange('siteCriteria')"
                />
                <NoteEditor
                    v-model="form.siteDescription"
                    :v="$v.form.siteDescription"
                    :readonly="readonly"
                    :dataCy="'siteDescriptionBody'"
                    @change="onChange('siteDescription')"
                />
                <NoteEditor
                    v-model="form.customKey"
                    :v="$v.form.customKey"
                    :readonly="readonly"
                    :editableTitle="true"
                    :dataCy="'customKeyBody'"
                    @change="onChange('customKey')"
                />
            </form>
        </div>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import { mapGetters } from "vuex";
import CommonComponents from "@/views/shared";

import { mergeNotes, NoteMedia, Notes, PortalNoteMedia, PortalStationNotes } from "./model";
import NoteEditor from "./NoteEditor.vue";
import { ActionTypes } from "@/store";
import { SnackbarStyle } from "@/store/modules/snackbar";

export default Vue.extend({
    name: "NotesForm",
    components: {
        ...CommonComponents,
        NoteEditor,
    },
    props: {
        station: {
            type: Object,
            required: true,
        },
        readonly: {
            type: Boolean,
            default: true,
        },
    },
    validations: {
        form: {
            studyObjective: {},
            sitePurpose: {},
            siteCriteria: {},
            siteDescription: {},
            customKey: {},
        },
    },
    data: () => {
        return {
            form: new Notes(),
            formBeforeChanges: new Notes(),
        };
    },
    computed: {
        ...mapGetters({ isAuthenticated: "isAuthenticated", isBusy: "isBusy" }),
        notes(): PortalStationNotes[] {
            return this.$state.notes.notes;
        },
        media(): PortalNoteMedia[] {
            return this.$state.notes.media;
        },
        completed(this: any) {
            const notesProgress = this.form.progress;
            const anyPhotos = NoteMedia.onlyPhotos(this.form.addedPhotos).length + NoteMedia.onlyPhotos(this.media).length > 0;
            const percentage = ((notesProgress.completed + anyPhotos) / (notesProgress.total + 1)) * 100;
            return percentage.toFixed(0);
        },
    },
    mounted(this: any) {
        this.form = Notes.createFrom({ notes: this.notes, media: this.media });
        this.formBeforeChanges = JSON.parse(JSON.stringify(this.form));
    },
    methods: {
        async onSave(): Promise<void> {
            this.$v.form.$touch();
            if (this.$v.form.$pending || this.$v.form.$error) {
                return;
            }

            const payload = mergeNotes({ notes: this.notes, media: this.media }, this.form);
            return this.$services.api
                .patchStationNotes(this.station.id, payload)
                .then(() => {
                    this.$store.dispatch(ActionTypes.NEED_NOTES, { id: this.station.id });
                    this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                        message: this.$tc("notes.updateSuccess"),
                        type: SnackbarStyle.success,
                    });
                    Notes.Keys.forEach((key) => {
                        this.$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, key);
                    });
                    this.$emit("saved");
                })
                .catch(() => {
                    this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                        message: this.$tc("notes.updateFail"),
                        type: SnackbarStyle.fail,
                    });
                });
        },
        onChange(key: string): void {
            if (this.form[key].body !== this.formBeforeChanges[key].body || this.form[key].title !== this.formBeforeChanges[key].title) {
                this.$store.dispatch(ActionTypes.NEW_DIRTY_FIELD, key);
            } else {
                this.$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, key);
            }
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/global";
@use "src/scss/notes";
</style>
