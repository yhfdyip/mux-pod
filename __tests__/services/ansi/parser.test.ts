/**
 * AnsiParser Unit Tests
 */
import { AnsiParser } from '@/services/ansi/parser';

describe('AnsiParser', () => {
  let parser: AnsiParser;

  beforeEach(() => {
    parser = new AnsiParser();
  });

  describe('parseLine', () => {
    it('should parse plain text', () => {
      const spans = parser.parseLine('Hello, World!');

      expect(spans).toHaveLength(1);
      expect(spans[0]?.text).toBe('Hello, World!');
      expect(spans[0]?.fg).toBeUndefined();
      expect(spans[0]?.bg).toBeUndefined();
    });

    it('should parse foreground color', () => {
      const spans = parser.parseLine('\x1b[32mgreen text\x1b[0m');

      expect(spans).toHaveLength(1);
      expect(spans[0]?.text).toBe('green text');
      expect(spans[0]?.fg).toBe(2); // green
    });

    it('should parse background color', () => {
      const spans = parser.parseLine('\x1b[41mred bg\x1b[0m');

      expect(spans).toHaveLength(1);
      expect(spans[0]?.text).toBe('red bg');
      expect(spans[0]?.bg).toBe(1); // red
    });

    it('should parse bold text', () => {
      const spans = parser.parseLine('\x1b[1mbold\x1b[0m');

      expect(spans).toHaveLength(1);
      expect(spans[0]?.text).toBe('bold');
      expect(spans[0]?.bold).toBe(true);
    });

    it('should parse multiple segments', () => {
      const spans = parser.parseLine('\x1b[31mred\x1b[0m normal \x1b[32mgreen\x1b[0m');

      expect(spans).toHaveLength(3);
      expect(spans[0]?.text).toBe('red');
      expect(spans[0]?.fg).toBe(1);
      expect(spans[1]?.text).toBe(' normal ');
      expect(spans[1]?.fg).toBeUndefined();
      expect(spans[2]?.text).toBe('green');
      expect(spans[2]?.fg).toBe(2);
    });

    it('should parse 256 colors', () => {
      const spans = parser.parseLine('\x1b[38;5;208morange\x1b[0m');

      expect(spans).toHaveLength(1);
      expect(spans[0]?.fg).toBe(208);
    });

    it('should parse bright colors', () => {
      const spans = parser.parseLine('\x1b[91mbright red\x1b[0m');

      expect(spans).toHaveLength(1);
      expect(spans[0]?.fg).toBe(9); // bright red
    });

    it('should handle empty string', () => {
      const spans = parser.parseLine('');

      expect(spans).toHaveLength(0);
    });

    it('should parse underline', () => {
      const spans = parser.parseLine('\x1b[4munderlined\x1b[0m');

      expect(spans).toHaveLength(1);
      expect(spans[0]?.underline).toBe(true);
    });

    it('should parse multiple attributes', () => {
      const spans = parser.parseLine('\x1b[1;31;4mbold red underline\x1b[0m');

      expect(spans).toHaveLength(1);
      expect(spans[0]?.bold).toBe(true);
      expect(spans[0]?.fg).toBe(1);
      expect(spans[0]?.underline).toBe(true);
    });
  });

  describe('parseLines', () => {
    it('should parse multiple lines', () => {
      const lines = parser.parseLines([
        'line 1',
        '\x1b[32mgreen line 2\x1b[0m',
        'line 3',
      ]);

      expect(lines).toHaveLength(3);
      expect(lines[0]?.spans[0]?.text).toBe('line 1');
      expect(lines[1]?.spans[0]?.fg).toBe(2);
      expect(lines[2]?.spans[0]?.text).toBe('line 3');
    });
  });

  describe('stripAnsi', () => {
    it('should strip ANSI codes', () => {
      const result = parser.stripAnsi('\x1b[32mgreen text\x1b[0m');

      expect(result).toBe('green text');
    });

    it('should handle plain text', () => {
      const result = parser.stripAnsi('plain text');

      expect(result).toBe('plain text');
    });
  });
});
