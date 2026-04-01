# Title Near-Duplicate Judgment Prompt

## Instructions

以下标题可能是关于同一新闻的不同报道。请判断哪些是近似重复的。

## 候选标题组

{title_list_with_ids}

_(Note: The agent fills this placeholder with candidate title pairs from Stage B. Each entry includes `id` and `title`, separated by newlines.)_

## 判断标准

- **"近似重复"**指：报道的是同一件事的同一个角度，只是来源/措辞不同
- **"不重复"**指：虽然主题相关，但报道的是不同事实或不同角度
- 同一事件的不同进展（如"发布"vs"评测"）不算重复，应保留
- 仅标题相似但实际内容不同的（如"XX公司发布Q1财报" vs "XX公司发布Q2财报"）不算重复

## 输出格式

返回 JSON 数组，每个元素为一组重复新闻的 ID 列表。无重复则返回空数组 `[]`。

**仅返回有效 JSON，不要添加 markdown 代码块或其他说明文字。**

示例（有重复）：
```
[["id1", "id2"], ["id3", "id4", "id5"]]
```

示例（无重复）：
```
[]
```
