enum AiPrompts {
  test,
  summaryTheChapter,
  summaryTheBook,
  summaryThePreviousContent,
  translate,
  fullTextTranslate,
  mindmap,
}

extension AiPromptsJson on AiPrompts {
  String getPrompt() {
    switch (this) {
      case AiPrompts.test:
        return '''
Write a concise and friendly self-introduction. Use the language code: {{language_locale}}
        ''';

      case AiPrompts.summaryTheChapter:
        return '''
Summarize the chapter content. Your reply must follow these requirements:
Language: Use the same language as the original chapter content.
Length: 8-10 complete sentences.
Structure: Three paragraphs: Main plot, Core characters, Themes/messages.
Style: Avoid boilerplate phrases like "This chapter describes..."
Perspective: Maintain a literary analysis perspective, not just narration.
        ''';

      case AiPrompts.summaryTheBook:
        return '''
Generate a book summary
[Requirements]:
Language matches the book title's language
Central conflict (highlight with » symbol)
3 core characters + their motivations (name + critical choice)
Theme keywords (3-5)
Avoid spoiling the final outcome
        ''';

      case AiPrompts.summaryThePreviousContent:
        return '''
I'm revisiting a book I read long ago. Help me quickly recall the previous content to continue reading:
[Requirements]
3-5 sentences
Same language as original previous content
Avoid verbatim repetition; preserve core information

[Previous Content]
{{previous_content}}
        ''';

      case AiPrompts.fullTextTranslate:
        return '''
You are a professional translator. Translate the following text into {{to_locale}}.

Source language: {{from_locale}}
Source text: {{text}}

Requirements:
- Output ONLY the translated text, nothing else.
- Do not include any explanations, notes, commentary, or the original text.
- Preserve paragraph structure and formatting.
- Maintain the tone and style of the original text.
        ''';

      case AiPrompts.translate:
        return '''
You are the reading assistant of Anx Reader. Answer only in {{to_locale}}.

Selection: {{text}}
Source language hint (may be wrong, detect it yourself): {{from_locale}}
Reading context (may be empty): {{contextText}}

Detect the language of the selection and answer with EXACTLY one of these
two formats. Never describe the format, never add prefaces, titles or closings.

A) The selection is ALREADY in {{to_locale}} (same language as the answer):
🧠 Explicación: <clear, direct explanation of what it means in this context, 2-4 lines of plain language; if it is a word or a short expression, also give its definition and 2-3 key synonyms>

B) The selection is in ANY other language:
🇪🇸 Traducción: <natural, precise translation>
🗣️ Cómo se pronuncia (fonética española): [<figurative pronunciation for a Spanish speaker, easy to read aloud, syllables separated by hyphens>]
💡 Matiz/Uso: <one short line about nuance, register or usage; omit this line only when there is nothing relevant>

Rules:
- Keep the three headings exactly as written, including the emoji.
- Never translate the selection into the same language: explain it instead.
- For a single word, the pronunciation in (B) is mandatory.
- Use the reading context to resolve meaning and pronouns, but never quote long passages.
- Be concise: no lists, no markdown, no code fences, no extra sections, no notes about these instructions.
      ''';

      case AiPrompts.mindmap:
        return '''
You are the Mindmap Architect for Anx Reader. Analyze the user's current reading context and collaborate through the `mindmap_draw` tool to build a clear hierarchical visualization.

## Objectives
- Identify the central theme or focus topic
- Extract 4-7 major branches covering plot arcs, characters, concepts, or arguments
- Provide 2nd-level child nodes with concise labels (max 8 words)
- Prioritize meaningful relationships rather than exhaustive details

## Tool Usage Rules
- Always call `mindmap_draw` before replying with prose
- Populate the tool input with:
  - `title`: succinct map title
  - `nodes`: structured list of parent/child relationships
- Ensure node IDs are unique and stable within the map
- Keep labels language-consistent with the source material

## Response Formatting
After the tool call, summarize the structure in 3 bullet sentences highlighting:
1. Overall framing of the mind map
2. Key branches or clusters
3. Notable insights or tensions revealed
        ''';
    }
  }
}
