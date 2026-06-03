/* global jest */
import wapiChannel from '../../channel/wapiChannel';
import ApiClient from '../../ApiClient';

describe('#wapiChannel', () => {
  it('creates correct instance', () => {
    expect(wapiChannel).toBeInstanceOf(ApiClient);
    expect(wapiChannel).toHaveProperty('createDevice');
    expect(wapiChannel).toHaveProperty('getQr');
    expect(wapiChannel).toHaveProperty('loginWithCode');
    expect(wapiChannel).toHaveProperty('getStatus');
    expect(wapiChannel).toHaveProperty('connectDevice');
  });

  describe('#createDevice', () => {
    it('calls correct endpoint', () => {
      const spy = jest
        .spyOn(wapiChannel, 'createDevice')
        .mockResolvedValue({ data: { success: true } });
      wapiChannel.createDevice(1);
      expect(spy).toHaveBeenCalledWith(1);
      spy.mockRestore();
    });
  });

  describe('#getQr', () => {
    it('calls correct endpoint', () => {
      const spy = jest
        .spyOn(wapiChannel, 'getQr')
        .mockResolvedValue({ data: { success: true, qr: 'qr-data' } });
      wapiChannel.getQr(1);
      expect(spy).toHaveBeenCalledWith(1);
      spy.mockRestore();
    });
  });

  describe('#loginWithCode', () => {
    it('calls correct endpoint with phone', () => {
      const spy = jest
        .spyOn(wapiChannel, 'loginWithCode')
        .mockResolvedValue({ data: { success: true } });
      wapiChannel.loginWithCode(1, '1234567890');
      expect(spy).toHaveBeenCalledWith(1, '1234567890');
      spy.mockRestore();
    });
  });

  describe('#getStatus', () => {
    it('calls correct endpoint', () => {
      const spy = jest
        .spyOn(wapiChannel, 'getStatus')
        .mockResolvedValue({ data: { success: true, status: 'connected' } });
      wapiChannel.getStatus(1);
      expect(spy).toHaveBeenCalledWith(1);
      spy.mockRestore();
    });
  });

  describe('#connectDevice', () => {
    it('calls correct endpoint with api token', () => {
      const spy = jest
        .spyOn(wapiChannel, 'connectDevice')
        .mockResolvedValue({ data: { success: true } });
      wapiChannel.connectDevice(1, 'test-token');
      expect(spy).toHaveBeenCalledWith(1, 'test-token');
      spy.mockRestore();
    });
  });
});
