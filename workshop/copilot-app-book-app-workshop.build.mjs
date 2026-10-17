import { initContext, loadDeck, finalizeDeck, builders, parseScriptArgs } from "../dist/index.js";
const args = parseScriptArgs();
const { ctx, root } = initContext(args.design, { mode: args.mode, logo: args.logo });
const deck = loadDeck(args.content, root);
let slideNumber = 0;
for (const slide of deck.slides ?? []) {
  slideNumber += 1;
  switch ((slide.type ?? "content").toLowerCase()) {
    case "title": builders.buildTitle(ctx, slide); break;
    case "divider": builders.buildDivider(ctx, { ...slide, slide_number: slideNumber }); break;
    case "closing": builders.buildClosing(ctx, slide); break;
    case "checklist": builders.buildChecklist(ctx, { ...slide, slide_number: slideNumber }); break;
    case "table": builders.buildTable(ctx, { ...slide, slide_number: slideNumber }); break;
    default: builders.buildContent(ctx, { ...slide, slide_number: slideNumber });
  }
}
await finalizeDeck(ctx, args.output, { root, strict: args.strict, embedFonts: args.embedFonts });
console.log(`Wrote ${args.output}`);