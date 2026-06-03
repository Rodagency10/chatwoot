import { vi } from 'vitest';
import wapiChannel from '../../channel/wapiChannel';
import ApiClient from '../../ApiClient';

describe('#wapiChannel', () => {
  it('creates correct instance', () => {
    expect(wapiChannel).toBeInstanceOf(ApiClient);
    expect(wapiChannel).toHaveProperty('createInbox');
    expect(wapiChannel).toHaveProperty('getQr');
    expect(wapiChannel).toHaveProperty('loginWithCode');
    expect(wapiChannel).toHaveProperty('getStatus');
    expect(wapiChannel).toHaveProperty('connect');
  });

  describe('#createInbox', () => {
    it('calls correct endpoint', () => {
      const spy = vi
        .spyOn(wapiChannel, 'createInbox')
        .mockResolvedValue({ data: { success: true } });
      wapiChannel.createInbox('Support');
      expect(spy).toHaveBeenCalledWith('Support');
      spy.mockRestore();
    });
  });

  describe('#getQr', () => {
    it('calls correct endpoint', () => {
      const spy = vi
        .spyOn(wapiChannel, 'getQr')
        .mockResolvedValue({ data: { success: true, qr: 'qr-data' } });
      wapiChannel.getQr(1);
      expect(spy).toHaveBeenCalledWith(1);
      spy.mockRestore();
    });
  });

  describe('#loginWithCode', () => {
    it('calls correct endpoint with phone', () => {
      const spy = vi
        .spyOn(wapiChannel, 'loginWithCode')
        .mockResolvedValue({ data: { success: true } });
      wapiChannel.loginWithCode(1, '1234567890');
      expect(spy).toHaveBeenCalledWith(1, '1234567890');
      spy.mockRestore();
    });
  });

  describe('#getStatus', () => {
    it('calls correct endpoint', () => {
      const spy = vi
        .spyOn(wapiChannel, 'getStatus')
        .mockResolvedValue({ data: { success: true, status: 'connected' } });
      wapiChannel.getStatus(1);
      expect(spy).toHaveBeenCalledWith(1);
      spy.mockRestore();
    });
  });

  describe('#connect', () => {
    it('calls correct endpoint', () => {
      const spy = vi
        .spyOn(wapiChannel, 'connect')
        .mockResolvedValue({ data: { success: true } });
      wapiChannel.connect(1);
      expect(spy).toHaveBeenCalledWith(1);
      spy.mockRestore();
    });
  });
});
