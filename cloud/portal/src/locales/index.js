import en from "./en/en.json";
import enModules from "./en/modules.json";
import es from "./es/es.json";
import esModules from "./es/modules.json";

export const defaultLocale = "enUS";

export const languages = {
    "en-US": { ...en, ...enModules },
    "es-ES": { ...es, ...esModules },
};

