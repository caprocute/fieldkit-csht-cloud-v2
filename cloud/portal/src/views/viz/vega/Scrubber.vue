<template>
    <div>
        <div class="viz scrubber"></div>
    </div>
</template>

<script lang="ts">
import _ from "lodash";
import Vue, { PropType } from "vue";
import { default as vegaEmbed } from "vega-embed";

import { isMobile } from "@/utilities";
import { TimeRange } from "../common";
import { TimeZoom, SeriesData } from "../viz";
import { ScrubberSpecFactory, ChartSettings } from "./ScrubberSpecFactory";
import { DataEvent } from "@/views/comments/model";

export default Vue.extend({
    name: "Scrubber",
    props: {
        series: {
            type: Array as PropType<SeriesData[]>,
            required: true,
        },
        visible: {
            type: Object as PropType<TimeRange>,
            required: true,
        },
        dragging: {
            type: Boolean,
            required: true,
        },
    },
    data(): {
        vega: any | null;
        scrubbed: number[] | null;
        scrubbing: boolean;
    } {
        return { vega: null, scrubbed: null, scrubbing: false };
    },
    async mounted(): Promise<void> {
        console.log("scrubber: mounted");
        await this.refresh();
    },
    watch: {
        async series(): Promise<void> {
            console.log("viz:", "scrubber: refresh(ignored, series)");
        },
        async dragging(dragging): Promise<void> {
            console.log("viz:", "scrubber: dragging", dragging, this.visible);
            this.pickRange(this.visible);
        },
        async visible(): Promise<void> {
            this.pickRange(this.visible);
        },
        async dataEvents(): Promise<void> {
            // console.log("scrubber: data-events");
            // await this.refresh();
        },
    },
    computed: {
        dataEvents(): DataEvent[] {
            return this.$state.discussion.dataEvents;
        },
    },
    created() {
        console.log("viz: scrubber: created");
        window.addEventListener("mouseup", this.mouseUp);
    },
    destroyed() {
        console.log("viz: scrubber: destroyed");
        window.removeEventListener("mouseup", this.mouseUp);
    },
    methods: {
        mouseUp(_event: Event) {
            // Only refresh zoomed area if we're scrubbing. Otherwise, spurious
            // brush signals, say from manually updating the initial brush area,
            // will cause scrubbing to contain values and we end up emitting the
            // time zoomed value. This will cause drop downs and the like to
            // close on mouseups.
            if (this.scrubbing) {
                if (this.scrubbed && this.scrubbed.length == 2) {
                    console.log("viz: vega:scrubber:brush-zoomed", this.scrubbed);
                    this.$emit("time-zoomed", new TimeZoom(null, new TimeRange(this.scrubbed[0], this.scrubbed[1])));
                    this.scrubbed = null;
                } else {
                    console.log("viz: vega:scrubber:brush-noop", this.scrubbed);
                    this.scrubbed = null;
                }
            }
            this.scrubbing = false;
        },
        async refresh(): Promise<void> {
            console.log("viz:", "scrubber: refresh");

            const factory = new ScrubberSpecFactory(
                this.series,
                new ChartSettings(this.visible, undefined, { w: 0, h: 0 }, false, false, isMobile()),
                (this.dataEvents || []).filter((event) => {
                    return this.series.every(
                        (seriesData) => event.start >= seriesData.queried.timeRange[0] && event.end <= seriesData.queried.timeRange[1]
                    );
                })
            );

            const spec = factory.create();

            const vegaInfo = await vegaEmbed(this.$el as HTMLElement, spec, {
                renderer: "svg",
                actions: { source: false, editor: false, compiled: false },
            });

            this.vega = vegaInfo;

            // eslint-disable-next-line
            vegaInfo.view.addSignalListener("brush", (_, value) => {
                // Only remember scrubbed value if we're scrubbing. May be
                // paranoid because we also check scrubbing in mouseup.
                if (this.scrubbing) {
                    // console.log("viz: vega:brush", value);
                    if (value.time) {
                        this.scrubbed = value.time;
                    } else if (this.series[0].queried) {
                        this.scrubbed = this.series[0].queried.timeRange;
                    }
                }
            });
            vegaInfo.view.addEventListener("mousedown", (_, value) => {
                console.log("signal:mousedown", value);
                // We need this to know if we should refresh on a future
                // mouseup, since the above brush signal gets invoked in more
                // situations than when the user is scrubbing.
                this.scrubbing = true;
            });
            /*
            vegaInfo.view.addSignalListener("scrub_handle_left", (_, value) => {
                console.log("signal:scrub-left", value);
            });
            vegaInfo.view.addSignalListener("scrub_handle_right", (_, value) => {
                console.log("signal:scrub-right", value);
            });
            vegaInfo.view.addSignalListener("brush_tuple", (_, value) => {
                console.log("signal:brush-tuple", value);
            });
            vegaInfo.view.addSignalListener("brush_modify", (_, value) => {
                console.log("signal:brush-modify", value);
            });
            */
            vegaInfo.view.addSignalListener("event_click", (_, value) => {
                this.$emit("event-clicked", value);
            });

            console.log("viz: scrubber", {
                state: vegaInfo.view.getState(),
                data: vegaInfo.view.data("data_1"),
            });

            this.pickRange(this.visible);
        },
        inflatedBrushTimes(times: TimeRange): number[] {
            const x = times.toArray().map((v) => this.vega.view.scale("x")(v));
            const minimumWidth = 5;
            const halfMinimumWidth = minimumWidth / 2;
            const width = x[1] - x[0];
            if (width > minimumWidth) {
                return x;
            }
            const middle = x[0] + width / 2;
            return [middle - halfMinimumWidth, middle + halfMinimumWidth];
        },
        async brush(times: TimeRange): Promise<void> {
            if (!this.vega || !this.series[0].queried) {
                console.log("viz: vega:scrubber:brushing-ignore");
                return;
            }

            // console.log("viz: vega:scrubber:brushing", times, x);
            const x = this.inflatedBrushTimes(times);

            try {
                await this.vega.view
                    .signal("brush_x", x)
                    .signal("brush_tuple", {
                        fields: [
                            {
                                field: "time",
                                channel: "x",
                                type: "R",
                            },
                        ],
                        values: times,
                    })
                    .runAsync();
            } catch (error) {
                console.log("viz: error", error);
            }
        },
        async pickRange(timeRange: TimeRange): Promise<void> {
            const first = this.series[0];
            if (first.ds) {
                await this.brush(timeRange);
            }
        },
    },
});
</script>

<style lang="scss">
@use "src/scss/variables";
.viz {
    width: 100%;
}
g.left_scrub:hover > path {
    cursor: ew-resize;
}
g.right_scrub:hover > path {
    cursor: ew-resize;
}
g.brush_brush:hover {
    cursor: grab;
}
g.brush_brush:hover:active {
    cursor: grabbing;
}
</style>
