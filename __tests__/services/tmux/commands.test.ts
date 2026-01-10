/**
 * TmuxCommands Unit Tests
 */
import { TmuxCommands, TmuxNotInstalledError } from '@/services/tmux/commands';
import type { ISSHClient } from '@/services/ssh/client';

describe('TmuxCommands', () => {
  let mockSSHClient: jest.Mocked<ISSHClient>;
  let tmux: TmuxCommands;

  beforeEach(() => {
    mockSSHClient = {
      connect: jest.fn(),
      disconnect: jest.fn(),
      isConnected: jest.fn().mockReturnValue(true),
      startShell: jest.fn(),
      write: jest.fn(),
      resize: jest.fn(),
      exec: jest.fn(),
      setEventHandlers: jest.fn(),
    };
    tmux = new TmuxCommands(mockSSHClient);
  });

  describe('listSessions', () => {
    it('should parse session list correctly', async () => {
      mockSSHClient.exec.mockResolvedValueOnce(
        'main\t1704067200\t1\t3\ndev\t1704153600\t0\t2\n'
      );

      const sessions = await tmux.listSessions();

      expect(sessions).toHaveLength(2);
      expect(sessions[0]?.name).toBe('main');
      expect(sessions[0]?.attached).toBe(true);
      expect(sessions[0]?.windowCount).toBe(3);
      expect(sessions[1]?.name).toBe('dev');
      expect(sessions[1]?.attached).toBe(false);
    });

    it('should return empty array when no sessions', async () => {
      mockSSHClient.exec.mockResolvedValueOnce('');

      const sessions = await tmux.listSessions();

      expect(sessions).toHaveLength(0);
    });

    it('should throw TmuxNotInstalledError when tmux not found', async () => {
      mockSSHClient.exec.mockRejectedValueOnce(new Error('tmux: command not found'));

      await expect(tmux.listSessions()).rejects.toThrow(TmuxNotInstalledError);
    });
  });

  describe('listWindows', () => {
    it('should parse window list correctly', async () => {
      mockSSHClient.exec.mockResolvedValueOnce(
        '0\teditor\t1\t2\n1\tserver\t0\t1\n'
      );

      const windows = await tmux.listWindows('main');

      expect(windows).toHaveLength(2);
      expect(windows[0]?.index).toBe(0);
      expect(windows[0]?.name).toBe('editor');
      expect(windows[0]?.active).toBe(true);
      expect(windows[0]?.paneCount).toBe(2);
    });
  });

  describe('listPanes', () => {
    it('should parse pane list correctly', async () => {
      mockSSHClient.exec.mockResolvedValueOnce(
        '0\t%0\t1\tbash\tpane\t80\t24\t0\t0\n1\t%1\t0\tvim\teditor\t80\t24\t5\t10\n'
      );

      const panes = await tmux.listPanes('main', 0);

      expect(panes).toHaveLength(2);
      expect(panes[0]?.index).toBe(0);
      expect(panes[0]?.id).toBe('%0');
      expect(panes[0]?.active).toBe(true);
      expect(panes[0]?.currentCommand).toBe('bash');
      expect(panes[0]?.width).toBe(80);
      expect(panes[0]?.height).toBe(24);
    });
  });

  describe('capturePane', () => {
    it('should return captured lines', async () => {
      mockSSHClient.exec.mockResolvedValueOnce('line1\nline2\nline3');

      const lines = await tmux.capturePane('main', 0, 0);

      expect(lines).toEqual(['line1', 'line2', 'line3']);
    });

    it('should handle empty output', async () => {
      mockSSHClient.exec.mockResolvedValueOnce('');

      const lines = await tmux.capturePane('main', 0, 0);

      expect(lines).toEqual([]);
    });
  });

  describe('sendKeys', () => {
    it('should send keys to pane', async () => {
      mockSSHClient.exec.mockResolvedValueOnce('');

      await tmux.sendKeys('main', 0, 0, 'ls -la');

      expect(mockSSHClient.exec).toHaveBeenCalledWith(
        expect.stringContaining('send-keys')
      );
    });

    it('should use -l flag for literal keys', async () => {
      mockSSHClient.exec.mockResolvedValueOnce('');

      await tmux.sendKeys('main', 0, 0, 'ls', true);

      expect(mockSSHClient.exec).toHaveBeenCalledWith(
        expect.stringContaining('-l')
      );
    });
  });

  describe('selectPane', () => {
    it('should select pane', async () => {
      mockSSHClient.exec.mockResolvedValueOnce('');

      await tmux.selectPane('main', 0, 0);

      expect(mockSSHClient.exec).toHaveBeenCalledWith(
        expect.stringContaining('select-pane')
      );
    });
  });
});
