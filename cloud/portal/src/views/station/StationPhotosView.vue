<template>
    <StandardLayout>
        <div class="container-wrap">
            <DoubleHeader
                :backRoute="projectId ? 'viewStation' : 'viewStationFromMap'"
                :title="$tc('station.allPhotos')"
                :backTitle="$tc('layout.backStationDashboard')"
                :backRouteParams="{ projectId, stationId }"
            >
                <template v-slot:default v-if="!readOnly">
                    <button class="button-social">
                        <label for="imageInput">
                            <i class="icon icon-photo"></i>
                            {{ $tc("station.btn.addPhotos") }}
                        </label>
                    </button>
                    <input id="imageInput" type="file" accept="image/jpeg, image/png" @change="upload" />
                </template>
            </DoubleHeader>

            <silent-box
                v-if="photos && photos.length > 0 && gallery.some((item) => item && item.src)"
                :gallery="gallery.filter((item) => item && item.src)"
                @silentbox-overlay-opened="togglePageScroll()"
                @silentbox-overlay-hidden="togglePageScroll()"
            >
                <!-- eslint-disable-next-line -->
                <template v-slot:silentbox-item="{ silentboxItem }" class="photo-wrap">
                    <button class="photo-options" v-if="!readOnly">
                        <ListItemOptions
                            :options="photoOptions"
                            @listItemOptionClick="onPhotoOptionClick($event, silentboxItem.photo)"
                        ></ListItemOptions>
                    </button>
                    <AuthenticatedPhoto
                        v-if="silentboxItem.photo"
                        :url="silentboxItem.photo.url"
                        :loading="silentboxItem.photo.id === loadingPhotoId"
                        @loading-change="silentboxItem.loading = $event"
                    />
                </template>
            </silent-box>

            <div v-else class="empty-photos">
                {{ $t("station.emptyPhotos") }}
            </div>
        </div>
    </StandardLayout>
</template>

<script lang="ts">
import Vue from "vue";
import StandardLayout from "@/views/StandardLayout.vue";
import DoubleHeader from "@/views/shared/DoubleHeader.vue";
import AuthenticatedPhoto from "@/views/shared/AuthenticatedPhoto.vue";
import { AddedPhoto, NoteMedia, PortalNoteMedia } from "@/views/notes/model";
import { ActionTypes } from "@/store";
import ListItemOptions, { ListItemOption } from "@/views/shared/ListItemOptions.vue";
import { SnackbarStyle } from "@/store/modules/snackbar";

export default Vue.extend({
    name: "StationPhotosView",
    components: {
        StandardLayout,
        DoubleHeader,
        AuthenticatedPhoto,
        ListItemOptions,
    },
    computed: {
        projectId(): number {
            return parseInt(this.$route.params.projectId, 10);
        },
        stationId(): number {
            return parseInt(this.$route.params.stationId, 10);
        },
        photos(): NoteMedia[] {
            if (this.$state.notes.media) {
                return NoteMedia.onlyPhotos(this.$state.notes.media);
            }
            return [];
        },
        media(): PortalNoteMedia[] {
            return this.$state.notes.media;
        },
        readOnly(): boolean {
            return this.$state.notes.readOnly;
        },
    },
    data: (): {
        photoOptions: ListItemOption[];
        loadingPhotoId: number | null;
        gallery: { src: string; photo: NoteMedia; loading: boolean }[];
    } => {
        return {
            photoOptions: [],
            loadingPhotoId: null,
            gallery: [],
        };
    },
    watch: {
        photos() {
            this.initGallery();
        },
    },
    methods: {
        async onPhotoOptionClick(event: string, photo: PortalNoteMedia) {
            if (event === "delete-photo") {
                await this.$confirm({
                    message: this.$tc("confirmDeletePhoto"),
                    button: {
                        no: this.$tc("cancel"),
                        yes: this.$tc("delete"),
                    },
                    callback: async (confirm) => {
                        if (confirm) {
                            this.loadingPhotoId = photo.id;
                            this.$services.api
                                .deleteMedia(photo.id)
                                .then(async () => {
                                    await this.$store.dispatch(ActionTypes.NEED_NOTES, { id: this.$route.params.stationId });
                                    await this.$store.dispatch(ActionTypes.CLEAR_STATION, this.$route.params.stationId);
                                })
                                .finally(() => {
                                    this.onFinishedPhotoAction(this.$tc("successDeletePhoto"), SnackbarStyle.success);
                                })
                                .catch(() => {
                                    this.onFinishedPhotoAction(this.$tc("somethingWentWrong"), SnackbarStyle.fail);
                                });
                        }
                    },
                });
            }
            if (event === "set-as-station-image") {
                this.loadingPhotoId = photo.id;
                this.$services.api
                    .setStationImage(this.stationId, photo.id)
                    .then(() => {
                        this.onFinishedPhotoAction(this.$tc("successSetAsStationPhoto"), SnackbarStyle.success);
                        this.$store.dispatch(ActionTypes.NEED_NOTES, { id: this.$route.params.stationId });
                    })
                    .catch(() => {
                        this.onFinishedPhotoAction(this.$tc("somethingWentWrong"), SnackbarStyle.fail);
                    });
            }
        },
        onFinishedPhotoAction(message: string, type: SnackbarStyle): void {
            this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, { message, type });
            this.loadingPhotoId = null;
        },
        upload(this: any, ev) {
            const image = ev.target.files[0];

            const reader = new FileReader();
            reader.onload = (ev) => {
                if (ev?.target?.result) {
                    const photo = new AddedPhoto(image.type, image, ev.target.result);
                    this.$services.api
                        .uploadStationMedia(this.stationId, photo.key, photo.file)
                        .then(() => {
                            this.$store.dispatch(ActionTypes.NEED_NOTES, { id: this.stationId });
                            this.onFinishedPhotoAction(this.$tc("successAddedPhoto"), SnackbarStyle.success);
                            return [];
                        })
                        .catch(() => {
                            this.onFinishedPhotoAction(this.$tc("somethingWentWrong"), SnackbarStyle.fail);
                        });
                }
            };

            reader.readAsDataURL(image);
        },
        initGallery(): void {
            this.gallery = this.photos.map((photo) => ({
                src: "",
                photo: photo,
                loading: true,
            }));
            this.photos.forEach((photo, index) => {
                this.$services.api.loadMedia(photo["url"]).then((src) => {
                    this.$set(this.gallery, index, {
                        src: src,
                        photo: photo,
                        loading: false,
                    });
                });
            });
        },
        togglePageScroll(): void {
            document.body.classList.toggle("disable-scrolling");
        },
    },
    mounted() {
        this.photoOptions = [
            {
                label: this.$tc("station.btn.setAsStationImage"),
                event: "set-as-station-image",
                icon: "icon-home",
            },
            {
                label: this.$tc("station.btn.deletePhoto"),
                event: "delete-photo",
                icon: "icon-trash",
            },
        ];
    },
    beforeMount(): Promise<any> {
        return this.$store.dispatch(ActionTypes.NEED_NOTES, { id: this.stationId });
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/mixins";
@use "src/scss/variables";

.photo-options {
    @include mixins.position(absolute, 20px 20px null null);
    width: 35px;
    height: 35px;
    background-color: #fff;
    border: solid 1px #cccdcf;
    padding: 0;
    border-radius: 50px;
    z-index: variables.$z-index-top;

    ::v-deep .options-trigger {
        padding: 0;
        display: flex;
        justify-content: center;
        align-items: center;
        margin-top: -6px;
        height: 100%;

        &:after {
            transform: translate(-1px, 4px);
            font-weight: bold;
        }
    }

    ::v-deep .options-btns {
        right: 30px;
        left: unset;
        top: 30px;
        border: solid 1px var(--color-border);
        border-radius: 1px;
        padding-right: 25px;

        > * {
            font-size: 14px;
        }
    }
}

input[type="file"] {
    display: none;
}

.button-social {
    padding: 0 20px;

    label {
        display: flex;
        align-items: center;
        cursor: pointer;
    }
}

.empty-photos {
    margin-top: 10px;
}

#silentbox-gallery {
    display: flex;
    flex-wrap: wrap;
    gap: 20px 10px;
    margin-top: 20px;

    @include mixins.bp-down(variables.$xs) {
        justify-content: space-between;
    }
}

::v-deep .silentbox-item {
    position: relative;
    background-color: #e2e4e6;
    height: 300px;
    min-width: 100px;

    /* Safari-specific fix */
    @supports (-webkit-hyphens: none) {
        flex: 0 0 calc(50% - 5px);
        width: calc(50% - 5px);
    }

    &:has(.spinner) {
        min-width: 250px;
        min-height: 250px;
    }

    @include mixins.bp-down(variables.$xs) {
        height: auto;
        max-height: 80vh;
        flex: 1 1 auto;

        /* Safari-specific fix for mobile */
        @supports (-webkit-hyphens: none) {
            flex: 1 1 100%;
            width: 100%;
        }

        &:nth-of-type(even) {
            .options-btns {
                right: auto;
            }
        }
    }

    img {
        object-fit: cover;
        border-radius: 2px;
        width: 100%;
        height: 100%;
    }
}

::v-deep #silentbox-overlay__arrow-buttons {
    @include mixins.bp-down(variables.$md) {
        .arrow-previous {
            left: 30px;
        }
        .arrow-next {
            right: 30px;
        }
    }

    @include mixins.bp-down(variables.$xs) {
        .arrow-previous {
            left: 15px;
        }
        .arrow-next {
            right: 15px;
        }
    }
}

::v-deep #silentbox-overlay__close-button .icon {
    @include mixins.bp-down(variables.$md) {
        left: 35px;
        top: -20px;
    }

    @include mixins.bp-down(variables.$xs) {
        left: 45px;
        top: -40px;
    }
}
</style>
