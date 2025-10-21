enum VoiceIntent { setStatusDriving, setStatusOnDuty, setStatusOffDuty, startPretrip, messageDispatch, showParking, showBreakPlan }

VoiceIntent? parseIntent(String transcript) {
  final t = transcript.toLowerCase();
  if (t.contains('set driving')) return VoiceIntent.setStatusDriving;
  if (t.contains('on duty')) return VoiceIntent.setStatusOnDuty;
  if (t.contains('off duty')) return VoiceIntent.setStatusOffDuty;
  if (t.contains('start pre-trip') || t.contains('pretrip')) return VoiceIntent.startPretrip;
  if (t.contains('message dispatch')) return VoiceIntent.messageDispatch;
  if (t.contains('parking')) return VoiceIntent.showParking;
  if (t.contains('break') || t.contains('rest')) return VoiceIntent.showBreakPlan;
  return null;
}
