package org.json;

import java.util.LinkedHashMap;
import java.util.Map;

public final class JSONObject {
    private final Map<String, Object> values = new LinkedHashMap<>();

    public JSONObject(String source) throws JSONException {
        Parser parser = new Parser(source);
        parser.parseObject(values);
    }

    public Object opt(String name) {
        return values.get(name);
    }

    public String optString(String name, String fallback) {
        Object value = values.get(name);
        return value instanceof String ? (String) value : fallback;
    }

    private static final class Parser {
        private final String source;
        private int index;

        Parser(String source) throws JSONException {
            if (source == null) {
                throw new JSONException("JSON source is null");
            }
            this.source = source;
        }

        void parseObject(Map<String, Object> values) throws JSONException {
            skipWhitespace();
            expect('{');
            skipWhitespace();
            if (take('}')) {
                finish();
                return;
            }
            while (true) {
                skipWhitespace();
                String key = readString();
                skipWhitespace();
                expect(':');
                skipWhitespace();
                values.put(key, readValue());
                skipWhitespace();
                if (take('}')) {
                    finish();
                    return;
                }
                expect(',');
            }
        }

        private Object readValue() throws JSONException {
            if (index >= source.length()) {
                throw new JSONException("missing JSON value");
            }
            if (source.charAt(index) == '"') {
                return readString();
            }
            int start = index;
            while (index < source.length()) {
                char value = source.charAt(index);
                if (value == ',' || value == '}' || Character.isWhitespace(value)) {
                    break;
                }
                index++;
            }
            String token = source.substring(start, index);
            if (token.isEmpty()) {
                throw new JSONException("empty JSON value");
            }
            if ("true".equals(token)) {
                return Boolean.TRUE;
            }
            if ("false".equals(token)) {
                return Boolean.FALSE;
            }
            if ("null".equals(token)) {
                return null;
            }
            try {
                return Long.valueOf(token);
            } catch (NumberFormatException error) {
                throw new JSONException("invalid JSON value: " + token);
            }
        }

        private String readString() throws JSONException {
            expect('"');
            StringBuilder result = new StringBuilder();
            while (index < source.length()) {
                char value = source.charAt(index++);
                if (value == '"') {
                    return result.toString();
                }
                if (value == '\\') {
                    if (index >= source.length()) {
                        throw new JSONException("unfinished JSON escape");
                    }
                    char escaped = source.charAt(index++);
                    switch (escaped) {
                        case '"': result.append('"'); break;
                        case '\\': result.append('\\'); break;
                        case '/': result.append('/'); break;
                        case 'b': result.append('\b'); break;
                        case 'f': result.append('\f'); break;
                        case 'n': result.append('\n'); break;
                        case 'r': result.append('\r'); break;
                        case 't': result.append('\t'); break;
                        default: throw new JSONException("unsupported JSON escape");
                    }
                } else {
                    result.append(value);
                }
            }
            throw new JSONException("unterminated JSON string");
        }

        private void finish() throws JSONException {
            skipWhitespace();
            if (index != source.length()) {
                throw new JSONException("trailing JSON content");
            }
        }

        private void skipWhitespace() {
            while (index < source.length() && Character.isWhitespace(source.charAt(index))) {
                index++;
            }
        }

        private boolean take(char expected) {
            if (index < source.length() && source.charAt(index) == expected) {
                index++;
                return true;
            }
            return false;
        }

        private void expect(char expected) throws JSONException {
            if (!take(expected)) {
                throw new JSONException("expected '" + expected + "'");
            }
        }
    }
}
