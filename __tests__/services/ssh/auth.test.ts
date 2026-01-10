/**
 * SSH Auth Helpers Unit Tests
 */
import {
  savePassword,
  loadPassword,
  deletePassword,
  validateAuthOptions,
  PASSWORD_KEY_PREFIX,
} from '@/services/ssh/auth';
import * as SecureStore from 'expo-secure-store';

describe('SSH Auth Helpers', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('savePassword', () => {
    it('should save password to SecureStore', async () => {
      const connectionId = 'test-id';
      const password = 'secret-password';

      await savePassword(connectionId, password);

      expect(SecureStore.setItemAsync).toHaveBeenCalledWith(
        `${PASSWORD_KEY_PREFIX}${connectionId}`,
        password
      );
    });

    it('should throw on empty password', async () => {
      await expect(savePassword('test-id', '')).rejects.toThrow();
    });
  });

  describe('loadPassword', () => {
    it('should load password from SecureStore', async () => {
      const connectionId = 'test-id';
      const password = 'secret-password';
      (SecureStore.getItemAsync as jest.Mock).mockResolvedValueOnce(password);

      const result = await loadPassword(connectionId);

      expect(result).toBe(password);
      expect(SecureStore.getItemAsync).toHaveBeenCalledWith(
        `${PASSWORD_KEY_PREFIX}${connectionId}`
      );
    });

    it('should return null when password not found', async () => {
      (SecureStore.getItemAsync as jest.Mock).mockResolvedValueOnce(null);

      const result = await loadPassword('non-existent');

      expect(result).toBeNull();
    });
  });

  describe('deletePassword', () => {
    it('should delete password from SecureStore', async () => {
      const connectionId = 'test-id';

      await deletePassword(connectionId);

      expect(SecureStore.deleteItemAsync).toHaveBeenCalledWith(
        `${PASSWORD_KEY_PREFIX}${connectionId}`
      );
    });
  });

  describe('validateAuthOptions', () => {
    it('should pass for password auth with password', () => {
      expect(() => {
        validateAuthOptions('password', { password: 'secret' });
      }).not.toThrow();
    });

    it('should fail for password auth without password', () => {
      expect(() => {
        validateAuthOptions('password', {});
      }).toThrow();
    });

    it('should pass for key auth with privateKey', () => {
      expect(() => {
        validateAuthOptions('key', { privateKey: '-----BEGIN RSA...' });
      }).not.toThrow();
    });

    it('should fail for key auth without privateKey', () => {
      expect(() => {
        validateAuthOptions('key', {});
      }).toThrow();
    });
  });
});
