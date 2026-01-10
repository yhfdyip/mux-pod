/**
 * Tmux Parser Unit Tests
 */
import {
  parseSessionLine,
  parseWindowLine,
  parsePaneLine,
  parseSessions,
  parseWindows,
  parsePanes,
} from '@/services/tmux/parser';

describe('tmux parser', () => {
  describe('parseSessionLine', () => {
    it('should parse valid session line', () => {
      const session = parseSessionLine('main\t1704067200\t1\t3');

      expect(session).not.toBeNull();
      expect(session?.name).toBe('main');
      expect(session?.created).toBe(1704067200000); // converted to ms
      expect(session?.attached).toBe(true);
      expect(session?.windowCount).toBe(3);
    });

    it('should return null for invalid line', () => {
      expect(parseSessionLine('')).toBeNull();
      expect(parseSessionLine('invalid')).toBeNull();
    });

    it('should handle attached=0', () => {
      const session = parseSessionLine('dev\t1704067200\t0\t1');

      expect(session?.attached).toBe(false);
    });
  });

  describe('parseWindowLine', () => {
    it('should parse valid window line', () => {
      const window = parseWindowLine('0\teditor\t1\t2');

      expect(window).not.toBeNull();
      expect(window?.index).toBe(0);
      expect(window?.name).toBe('editor');
      expect(window?.active).toBe(true);
      expect(window?.paneCount).toBe(2);
    });

    it('should return null for invalid line', () => {
      expect(parseWindowLine('')).toBeNull();
      expect(parseWindowLine('invalid')).toBeNull();
    });
  });

  describe('parsePaneLine', () => {
    it('should parse valid pane line', () => {
      const pane = parsePaneLine('0\t%0\t1\tbash\ttitle\t80\t24\t0\t0');

      expect(pane).not.toBeNull();
      expect(pane?.index).toBe(0);
      expect(pane?.id).toBe('%0');
      expect(pane?.active).toBe(true);
      expect(pane?.currentCommand).toBe('bash');
      expect(pane?.title).toBe('title');
      expect(pane?.width).toBe(80);
      expect(pane?.height).toBe(24);
      expect(pane?.cursorX).toBe(0);
      expect(pane?.cursorY).toBe(0);
    });

    it('should return null for invalid line', () => {
      expect(parsePaneLine('')).toBeNull();
      expect(parsePaneLine('invalid')).toBeNull();
    });
  });

  describe('parseSessions', () => {
    it('should parse multiple sessions', () => {
      const output = 'main\t1704067200\t1\t3\ndev\t1704153600\t0\t2\n';
      const sessions = parseSessions(output);

      expect(sessions).toHaveLength(2);
    });

    it('should skip invalid lines', () => {
      const output = 'main\t1704067200\t1\t3\ninvalid\ndev\t1704153600\t0\t2\n';
      const sessions = parseSessions(output);

      expect(sessions).toHaveLength(2);
    });
  });

  describe('parseWindows', () => {
    it('should parse multiple windows', () => {
      const output = '0\teditor\t1\t2\n1\tserver\t0\t1\n';
      const windows = parseWindows(output);

      expect(windows).toHaveLength(2);
    });
  });

  describe('parsePanes', () => {
    it('should parse multiple panes', () => {
      const output = '0\t%0\t1\tbash\tpane\t80\t24\t0\t0\n1\t%1\t0\tvim\teditor\t80\t24\t5\t10\n';
      const panes = parsePanes(output);

      expect(panes).toHaveLength(2);
    });
  });
});
