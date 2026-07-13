const retiredEnglishState = /\b(?:safe|watch|danger|unknown)\b/i;
const supersededEnglishDisplayLabel = /^\s*(?:[-*]\s*)?(?:Enough|Unavailable)\s*(?:[.!:：-]|$)/;
const retiredChineseStateSequence = /安全\s*[/／·、]\s*注意\s*[/／·、]\s*危(?:险|險)\s*[/／·、]\s*未知/;
const retiredChineseBadge = /(?:菜单栏|狀態欄|状态栏|膠囊|胶囊|状态|狀態|显示|顯示)\s*(?:为|為|[:：])?\s*(?:安全|注意|危(?:险|險)|未知)\s*(?:\d+(?:\.\d+)?%|[/／·])/;
const retiredBudgetCopy = /daily[- ]budget|today's sustainable|今天的可持续|今天可持续|今日预算|今日可用预算|最近周速度区间/i;

export function retiredProductCopyReason(line: string): string | null {
  if (/^\s*(?:[-*]\s*)?`(?:state|status)`\s*[:：]/i.test(line)) return null;
  const prose = line.replace(/`[^`]*`/g, "");
  if (retiredEnglishState.test(prose) || supersededEnglishDisplayLabel.test(prose)) {
    return "retired English weekly state label";
  }
  if (retiredChineseStateSequence.test(prose) || retiredChineseBadge.test(prose)) {
    return "retired Chinese weekly state label";
  }
  if (retiredBudgetCopy.test(prose)) return "retired weekly pacing copy";
  return null;
}
