.import "../../../Common/GridLayout.js" as GridLayout

function resolve(definitions, saved) {
    const source = Array.isArray(saved) ? saved : definitions.filter(d => d.enabled !== false);
    const seen = Object.create(null);
    return source.filter(item => {
        if (!item || typeof item.id !== "string" || seen[item.id])
            return false;
        seen[item.id] = true;
        return true;
    }).map(item => {
        const spec = definitions.find(d => d.id === item.id);
        if (!spec)
            return item;
        const widget = {
            id: item.id,
            w: GridLayout.dimension(item.w, spec.minW, spec.maxW, spec.w),
            h: GridLayout.dimension(item.h, spec.minH, spec.maxH, spec.h),
            graphics: typeof item.graphics === "boolean" ? item.graphics : true
        };
        if (Number.isFinite(item.col) && Number.isFinite(item.row)) {
            widget.col = item.col;
            widget.row = item.row;
        }
        return widget;
    });
}
