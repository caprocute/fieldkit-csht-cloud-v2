<template>
    <div class="vega-embed vega-embed--dummy">
        <details ref="vegaExportOptions">
            <summary>
                <svg viewBox="0 0 20 20" fill="currentColor" stroke="none" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
                    <g id="icon_SaveAs" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd" stroke-linecap="round">
                        <line
                            x1="7.96030045"
                            y1="1"
                            x2="7.96030045"
                            y2="11"
                            id="Path-2"
                            stroke="#2C3E50"
                            stroke-width="1.5"
                            stroke-linejoin="round"
                        ></line>
                        <polyline
                            id="Path-9"
                            stroke="#2C3E50"
                            stroke-width="1.5"
                            stroke-linejoin="bevel"
                            points="12.8961983 6.50366211 8.05585126 11 2.92245537 6.50366211"
                        ></polyline>
                        <polyline
                            id="Path-10"
                            stroke="#2C3E50"
                            stroke-width="1.5"
                            stroke-linejoin="round"
                            points="1 12.5363846 1 16.5 15.1181831 16.5 15.1181831 12.5363846"
                        ></polyline>
                    </g>
                </svg>
                <span class="save-label">{{ $t("dataView.saveAs") }}</span>
            </summary>
            <div class="vega-actions">
                <a href="" @click.prevent="exportAsSVG()">{{ $t("dataView.saveAsSvg") }}</a>
                <a href="" @click.prevent="exportAsPNG()">{{ $t("dataView.saveAsPng") }}</a>
            </div>
        </details>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import html2canvas from "html2canvas";
import { isMobile } from "@/utilities";
import { Project } from "@/api";

const EXPORT_CONFIG = {
    scaleFactor: 3,
    headerChartGap: 80,
    PNG: {
        width: 3840,
        height: 2160,
        mobile: {
            width: 1800,
            height: 2500,
        },
    },
    SVG: {
        width: 1920,
        height: 1080,
        mobile: {
            width: 1800,
            height: 2500,
        },
    },
};

export default Vue.extend({
    name: "ExportChartButton",
    props: {
        vega: {
            required: true,
        },
        series: {
            type: Array,
            required: false,
            default: () => [],
        },
    },
    data(): {
        tempInstance: Vue | null;
    } {
        return {
            tempInstance: null,
        };
    },
    mounted() {
        document.addEventListener("click", this.handleClick);
    },
    beforeDestroy() {
        document.removeEventListener("click", this.handleClick);
    },
    methods: {
        handleClick() {
            const detailsElement = this.$refs.vegaExportOptions as HTMLHtmlElement;
            detailsElement.removeAttribute("open");
        },
        downloadFile(content: string | Blob, fileName: string, mimeType: string) {
            const blob = typeof content === "string" ? new Blob([content], { type: mimeType }) : content;
            const link = document.createElement("a");
            const url = URL.createObjectURL(blob);
            link.href = url;
            link.download = fileName;
            link.click();
            URL.revokeObjectURL(url);
        },
        getExportConfig(type: "PNG" | "SVG") {
            const baseConfig = EXPORT_CONFIG[type];
            const isMobileDevice = isMobile();

            if (isMobileDevice) {
                return {
                    width: baseConfig.mobile.width,
                    height: baseConfig.mobile.height,
                    scaleFactor: EXPORT_CONFIG.scaleFactor,
                    headerChartGap: EXPORT_CONFIG.headerChartGap,
                    chartScale: 1,
                };
            }

            return {
                width: baseConfig.width,
                height: baseConfig.height,
                scaleFactor: EXPORT_CONFIG.scaleFactor,
                headerChartGap: EXPORT_CONFIG.headerChartGap,
                chartScale: 1,
            };
        },
        calculateChartPosition(headerCanvas: HTMLCanvasElement, chartCanvas: HTMLCanvasElement, config: any) {
            const headerScale = config.width / headerCanvas.width;
            const headerHeight = headerCanvas.height * headerScale;
            const chartAreaY = headerHeight + config.headerChartGap;
            const chartAreaHeight = config.height - chartAreaY;

            const isMobileDevice = isMobile();
            const chartPaddingLeft = isMobileDevice ? 40 : 80;
            const chartPaddingRight = isMobileDevice ? 40 : 20;
            const chartAreaWidth = config.width - chartPaddingLeft - chartPaddingRight;

            const chartScale = Math.min(chartAreaWidth / chartCanvas.width, chartAreaHeight / chartCanvas.height);
            const finalChartScale = chartScale * (config.chartScale || 1);

            const chartWidth = chartCanvas.width * finalChartScale;
            const chartHeight = chartCanvas.height * finalChartScale;
            const chartX = chartPaddingLeft + (chartAreaWidth - chartWidth) / 2 - 10;

            return {
                headerScale,
                headerHeight,
                chartAreaY,
                chartPaddingLeft,
                chartPaddingRight,
                chartAreaWidth,
                finalChartScale,
                chartWidth,
                chartHeight,
                chartX,
            };
        },
        compositeChartAndHeader(headerCanvas: HTMLCanvasElement, chartCanvas: HTMLCanvasElement, config: any): HTMLCanvasElement {
            const finalCanvas = document.createElement("canvas");
            finalCanvas.width = config.width;
            finalCanvas.height = config.height;

            const ctx = finalCanvas.getContext("2d");
            if (!ctx) throw new Error("Could not get canvas context");

            ctx.fillStyle = "white";
            ctx.fillRect(0, 0, config.width, config.height);

            const position = this.calculateChartPosition(headerCanvas, chartCanvas, config);
            const headerWidth = config.width;

            ctx.drawImage(headerCanvas, 0, 0, headerWidth, position.headerHeight);
            ctx.drawImage(chartCanvas, position.chartX, position.chartAreaY, position.chartWidth, position.chartHeight);

            return finalCanvas;
        },
        async exportAsPNG() {
            if (!this.vega) return;

            const htmlElement = await this.createExportContent();
            if (!htmlElement) return;

            try {
                const config = this.getExportConfig("PNG");

                const headerCanvas = await html2canvas(htmlElement, {
                    scale: config.scaleFactor,
                    backgroundColor: "#ffffff",
                    logging: false,
                });

                const vegaInfo = this.vega as { view: any };

                const chartCanvas = await this.createNormalizedChart(vegaInfo);

                const finalCanvas = this.compositeChartAndHeader(headerCanvas, chartCanvas, config);

                finalCanvas.toBlob((blob) => {
                    if (blob) {
                        this.downloadFile(
                            blob,
                            (this.vega as { embedOptions: { downloadFileName: string } }).embedOptions.downloadFileName,
                            "image/png"
                        );
                    }
                });
            } catch (error) {
                console.error("Error exporting the chart as PNG:", error);
            } finally {
                this.cleanupExportContent();
            }
        },
        async exportAsSVG() {
            if (!this.vega) return;

            const htmlElement = await this.createExportContent();
            if (!htmlElement) return;

            try {
                const config = this.getExportConfig("SVG");

                const isMobileDevice = isMobile();
                if (!isMobileDevice) {
                    config.chartScale = 1.05;
                }

                const headerCanvas = await html2canvas(htmlElement, {
                    scale: config.scaleFactor,
                    backgroundColor: "#ffffff",
                    logging: false,
                });
                const headerImage = headerCanvas.toDataURL("image/png");

                const vegaInfo = this.vega as { view: any };
                const chartSVG = await vegaInfo.view.toSVG(config.scaleFactor);
                const chartCanvas = await vegaInfo.view.toCanvas(config.scaleFactor);

                const position = this.calculateChartPosition(headerCanvas, chartCanvas, config);
                const headerWidth = config.width;

                // Position adjustments to match PNG positioning
                const leftAdjustment = 0;
                const topAdjustment = 40;
                const adjustedChartX = position.chartX - leftAdjustment;
                const adjustedChartY = position.chartAreaY - topAdjustment;

                const combinedSVG = `
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${config.width} ${config.height}">
                        <rect width="100%" height="100%" fill="white"/>
                        <image x="0" y="0" width="${headerWidth}" height="${position.headerHeight}" href="${headerImage}"/>
                        <g transform="translate(${adjustedChartX}, ${adjustedChartY}) scale(${position.finalChartScale})">
                            ${chartSVG}
                        </g>
                    </svg>
                `;

                const blob = new Blob([combinedSVG], { type: "image/svg+xml;charset=utf-8" });
                const url = URL.createObjectURL(blob);

                const link = document.createElement("a");
                link.href = url;
                link.download = (this.vega as { embedOptions: { downloadFileName: string } }).embedOptions.downloadFileName + ".svg";
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);

                URL.revokeObjectURL(url);
            } catch (error) {
                console.error("Error exporting the chart as SVG:", error);
            } finally {
                this.cleanupExportContent();
            }
        },
        async createExportContent(): Promise<HTMLElement | null> {
            const stationSensorPairs = this.series.map((s: any) => ({
                stationName: s.vizInfo?.station?.name || "Unknown Station",
                sensorName: s.vizInfo?.name || "Unknown Sensor",
            }));

            const partnerCustomization = await import("@/views/shared/partners").then((m) => m.getPartnerCustomization());
            let project: Project | null = null;

            if (partnerCustomization && partnerCustomization.projectId === 174) {
                try {
                    project = await this.$services.api.getProject(partnerCustomization.projectId);
                } catch (error) {
                    console.warn("Failed to load project for export:", error);
                }
            }

            const ExportChartContentModule = await import("./ExportChartContent.vue");
            const ExportChartContentComponent = ExportChartContentModule.default;

            const ComponentClass = Vue.extend(ExportChartContentComponent);
            const instance = new ComponentClass({
                propsData: {
                    stationSensorPairs,
                    project,
                },
            });

            instance.$mount();
            instance.$el.id = "export-chart-content-temp";
            document.body.appendChild(instance.$el);

            (this as any).tempInstance = instance;

            await new Promise((resolve) => setTimeout(resolve, 500));

            if (project) {
                let attempts = 0;
                while (attempts < 10) {
                    const photoElement = instance.$el.querySelector(".photo-container") as HTMLElement;
                    if (photoElement && photoElement.style.backgroundImage && photoElement.style.backgroundImage !== "none") {
                        break;
                    }
                    await new Promise((resolve) => setTimeout(resolve, 200));
                    attempts++;
                }
            }

            return instance.$el as HTMLElement;
        },
        cleanupExportContent() {
            if ((this as any).tempInstance) {
                document.body.removeChild((this as any).tempInstance.$el);
                (this as any).tempInstance.$destroy();
                (this as any).tempInstance = null;
            }
        },
        async createNormalizedChart(vegaInfo: any): Promise<HTMLCanvasElement> {
            try {
                return await vegaInfo.view.toCanvas(3);
            } catch (error) {
                console.warn("Failed to create chart canvas:", error);
                return await vegaInfo.view.toCanvas(2);
            }
        },
    },
});
</script>
