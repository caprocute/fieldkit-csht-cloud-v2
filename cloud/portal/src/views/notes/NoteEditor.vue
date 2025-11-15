<template>
    <div class="note-editor">
        <div class="title">
            <TextAreaField v-if="editingTitle" v-model="title" :data-cy="'customKeyTitle'" />
            <template v-else>
                <template v-if="isTranslationKey(title)">{{ $t(title) }}</template>
                <template v-else>{{ title }}</template>
            </template>
            <a
                class="edit-btn"
                v-if="editableTitle && !editingTitle && !readonly"
                @click="editingTitle = !editingTitle"
                data-cy="editCustomKey"
            >
                {{ $t("notes.customTitleEditLabel") }}
            </a>
        </div>
        <div class="field" v-if="!readonly">
            <TextAreaField v-model="body" @input="v.$touch()" :data-cy="dataCy" />
        </div>
        <div class="field" v-if="readonly">
            <template v-if="note.body">{{ note.body }}</template>
            <template v-if="!note.body">
                <div class="no-data-yet">{{ $t("notes.noFieldData") }}</div>
            </template>
        </div>
        <div class="attached-audio" v-for="audio in note.audio" v-bind:key="audio.key">
            <div class="audio-title">
                {{ audio.key }}
            </div>
            <AudioPlayer :url="audio.url" />
        </div>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import CommonComponents from "@/views/shared";
import AudioPlayer from "./AudioPlayer.vue";

export default Vue.extend({
    model: {
        prop: "note",
        event: "change",
    },
    name: "NoteEditor",
    components: {
        ...CommonComponents,
        AudioPlayer,
    },
    props: {
        readonly: {
            type: Boolean,
            default: false,
        },
        note: {
            type: Object,
            required: true,
        },
        v: {
            type: Object,
            required: true,
        },
        editableTitle: {
            type: Boolean,
            default: false,
        },
        dataCy: {
            type: String,
            default: "",
        },
    },
    data() {
        return {
            editingTitle: false,
        };
    },
    computed: {
        body: {
            get(this: any) {
                return this.note.body;
            },
            set(this: any, value) {
                this.$emit("change", this.note.withBody(value, this.note.title));
            },
        },
        title: {
            get(this: any) {
                if (this.editingTitle) {
                    return this.note.title;
                }
                return this.note.title || this.note.help.title;
            },
            set(this: any, value) {
                this.$emit("change", this.note.withBody(this.note.body, value));
            },
        },
    },
    methods: {
        isTranslationKey(text: string | undefined): boolean {
            return Boolean(text && typeof text === "string" && text.startsWith("notes.fields."));
        },
    },
    mounted() {
        this.$root.$on("language-changed", this.$forceUpdate);
    },
    beforeDestroy() {
        this.$root.$off("language-changed", this.$forceUpdate);
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/mixins";
@use "src/scss/variables";

.attached-audio {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    margin-bottom: 10px;
    border: 1px solid var(--color-border);
    border-radius: 4px;
    background-color: #fcfcfc;
    padding: 8px;
}

.audio-title {
    font-size: 14px;
    font-weight: 500;
    margin-right: auto;

    @include mixins.bp-down(variables.$xs) {
        flex-basis: 100%;
    }
}

.title {
    font-size: 16px;
    font-weight: 500;
    display: flex;
    align-items: center;

    @include mixins.bp-down(variables.$xs) {
        font-size: 14px;
    }
}

.no-data-yet {
    color: #6a6d71;
    font-size: 13px;
    padding-top: 0.5em;
}

.edit-btn {
    opacity: 0.4;
    font-size: 12px;
    cursor: pointer;
    margin-left: 8px;
}

::v-deep .title textarea {
    padding-top: 0;
}
</style>
