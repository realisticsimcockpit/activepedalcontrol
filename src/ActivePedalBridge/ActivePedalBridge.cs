using GameReaderCommon;
using SimHub.Plugins;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Windows.Controls;
using System.Windows.Media;

namespace ActivePedalDashboard
{
    [PluginDescription("Dashboard bridge for DiyFfbPedal. Reads live plugin state and forwards dashboard actions to the plugin.")]
    [PluginAuthor("Realistic Simcockpit")]
    [PluginName("ActivePedalBridge")]
    public class ActivePedalBridge : IPlugin, IDataPlugin, IWPFSettingsV2
    {
        private const BindingFlags AnyInstance = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
        private static readonly string[] PedalNames = { "Clutch", "Brake", "Throttle" };
        private static readonly string[] EffectKeys = { "ABS", "RPM", "Gforce", "WheelSlip", "RoadImpact" };

        private PluginManager _pluginManager;
        private object _pedalPlugin;
        private string _lastError = string.Empty;
        private DateTime _lastPluginLookup = DateTime.MinValue;
        private DateTime _lastConfigListRefresh = DateTime.MinValue;

        public PluginManager PluginManager { get; set; }
        public ImageSource PictureIcon
        {
            get { return null; }
        }

        public string LeftMenuTitle
        {
            get { return "Pedal Bridge"; }
        }

        public void Init(PluginManager pluginManager)
        {
            _pluginManager = pluginManager;

            this.AttachDelegate("BridgeStatus", () => FindPedalPlugin() != null ? "PLUGIN OK" : "PLUGIN MISSING");
            this.AttachDelegate("LastError", () => _lastError);
            this.AttachDelegate("SelectedPedal", () => GetSelectedPedalName());
            this.AttachDelegate("CurrentProfile", () => GetStringFromMemberPath("ProfileServicePlugin.CurrentGameProfile", "--", true));

            for (int pedal = 0; pedal < PedalNames.Length; pedal++)
            {
                int p = pedal;
                string pedalName = PedalNames[p];

                AddTextDelegate(string.Format("{0}.TravelMinText", pedalName), () => FormatValue(ReadConfigNumber(p, "pedalStartPosition"), "0", "%"));
                AddTextDelegate(string.Format("{0}.TravelMaxText", pedalName), () => FormatValue(ReadConfigNumber(p, "pedalEndPosition"), "0", "%"));
                AddTextDelegate(string.Format("{0}.PreloadText", pedalName), () => FormatValue(ReadConfigNumber(p, "preloadForce"), "0.#", "kg"));
                AddTextDelegate(string.Format("{0}.MaxForceText", pedalName), () => FormatValue(ReadConfigNumber(p, "maxForce"), "0.#", "kg"));
                AddTextDelegate(string.Format("{0}.ConnectionStatus", pedalName), () => ReadConnectionStatus(p));
                AddTextDelegate(string.Format("{0}.InputText", pedalName), () => FormatValue(ReadInputPercent(p), "0", "%"));

                this.AttachDelegate(string.Format("{0}.TravelMin", pedalName), () => ReadConfigNumber(p, "pedalStartPosition"));
                this.AttachDelegate(string.Format("{0}.TravelMax", pedalName), () => ReadConfigNumber(p, "pedalEndPosition"));
                this.AttachDelegate(string.Format("{0}.Preload", pedalName), () => ReadConfigNumber(p, "preloadForce"));
                this.AttachDelegate(string.Format("{0}.MaxForce", pedalName), () => ReadConfigNumber(p, "maxForce"));
                this.AttachDelegate(string.Format("{0}.ConnectionReady", pedalName), () => IsPedalReady(p) ? 1 : 0);
                this.AttachDelegate(string.Format("{0}.Input", pedalName), () => ReadInputPercent(p));

                AddConfigActions(p, pedalName, "TravelMin", "pedalStartPosition", 1.0);
                AddConfigActions(p, pedalName, "TravelMax", "pedalEndPosition", 1.0);
                AddConfigActions(p, pedalName, "Preload", "preloadForce", 1.0);
                AddConfigActions(p, pedalName, "MaxForce", "maxForce", 1.0);

                for (int configIndex = 0; configIndex < 5; configIndex++)
                {
                    int index = configIndex;
                    int slot = configIndex + 1;
                    AddTextDelegate(string.Format("{0}.Config.{1}.Name", pedalName, slot), () => ReadConfigListName(index));
                    AddTextDelegate(string.Format("{0}.Config.{1}.StatusText", pedalName, slot), () => ReadConfigStatusText(p, index));
                    this.AttachDelegate(string.Format("{0}.Config.{1}.Visible", pedalName, slot), () => GetConfigListItem(index) != null ? 1 : 0);
                    this.AttachDelegate(string.Format("{0}.Config.{1}.Active", pedalName, slot), () => IsConfigActive(p, index) ? 1 : 0);
                    this.AttachDelegate(string.Format("{0}.Config.{1}.Startup", pedalName, slot), () => IsConfigStartup(p, index) ? 1 : 0);
                    this.AddAction(string.Format("{0}.Config.{1}.Apply", pedalName, slot), (a, b) => ApplyConfigToPedal(p, index));
                }

                foreach (string effectKey in EffectKeys)
                {
                    string key = effectKey;
                    AddTextDelegate(string.Format("{0}.Effect.{1}Text", pedalName, key), () => ReadEffectEnabled(p, key) ? "ON" : "OFF");
                    this.AttachDelegate(string.Format("{0}.Effect.{1}", pedalName, key), () => ReadEffectEnabled(p, key) ? 1 : 0);
                    this.AddAction(string.Format("{0}.Effect.{1}.Toggle", pedalName, key), (a, b) => ToggleEffect(p, key));
                    this.AddAction(string.Format("{0}.Effect.{1}.On", pedalName, key), (a, b) => SetEffect(p, key, true));
                    this.AddAction(string.Format("{0}.Effect.{1}.Off", pedalName, key), (a, b) => SetEffect(p, key, false));
                }
            }

            this.AddAction("Refresh", (a, b) =>
            {
                _lastConfigListRefresh = DateTime.MinValue;
                RefreshPedalPlugin(true);
            });
        }

        public void DataUpdate(PluginManager pluginManager, ref GameData data)
        {
            if ((DateTime.Now - _lastPluginLookup).TotalSeconds > 5)
            {
                RefreshPedalPlugin(false);
            }
        }

        public void End(PluginManager pluginManager)
        {
        }

        public Control GetWPFSettingsControl(PluginManager pluginManager)
        {
            return null;
        }

        private void AddTextDelegate(string name, Func<string> provider)
        {
            this.AttachDelegate(name, provider);
        }

        private void AddConfigActions(int pedal, string pedalName, string label, string fieldName, double step)
        {
            this.AddAction(string.Format("{0}.{1}.Down", pedalName, label), (a, b) => ChangeConfigValue(pedal, fieldName, -step));
            this.AddAction(string.Format("{0}.{1}.Up", pedalName, label), (a, b) => ChangeConfigValue(pedal, fieldName, step));
        }

        private object FindPedalPlugin()
        {
            if (_pedalPlugin != null)
            {
                return _pedalPlugin;
            }

            return RefreshPedalPlugin(false);
        }

        private object RefreshPedalPlugin(bool force)
        {
            if (!force && _pedalPlugin != null)
            {
                return _pedalPlugin;
            }

            _lastPluginLookup = DateTime.Now;
            if (_pluginManager == null)
            {
                _lastError = "PluginManager unavailable";
                return null;
            }

            try
            {
                foreach (IPlugin plugin in _pluginManager.GetPlugins<IPlugin>())
                {
                    if (plugin == null || ReferenceEquals(plugin, this))
                    {
                        continue;
                    }

                    Type type = plugin.GetType();
                    string assembly = type.Assembly.GetName().Name;
                    if (type.Name == "DIY_FFB_Pedal" ||
                        string.Equals(type.FullName, "DiyFfbPedal.DIY_FFB_Pedal", StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(type.FullName, "User.PluginSdkDemo.DIY_FFB_Pedal", StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(assembly, "DiyFfbPedal", StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(assembly, "DiyActivePedal", StringComparison.OrdinalIgnoreCase))
                    {
                        _pedalPlugin = plugin;
                        _lastError = string.Empty;
                        return _pedalPlugin;
                    }
                }

                _pedalPlugin = null;
                _lastError = "DiyFfbPedal plugin not found";
                return null;
            }
            catch (Exception ex)
            {
                _pedalPlugin = null;
                _lastError = ex.Message;
                return null;
            }
        }

        private double ReadConfigNumber(int pedal, string fieldName)
        {
            object config;
            Array ignoredArray;
            string ignoredSource;
            if (!TryGetConfig(pedal, out config, out ignoredArray, out ignoredSource))
            {
                return double.NaN;
            }

            object payload = GetMember(config, "payloadPedalConfig_");
            object value = GetMember(payload, fieldName);
            return ToDouble(value);
        }

        private bool ChangeConfigValue(int pedal, string fieldName, double delta)
        {
            object config;
            Array configArray;
            string ignoredSource;
            if (!TryGetConfig(pedal, out config, out configArray, out ignoredSource))
            {
                _lastError = string.Format("No live config available for {0}", PedalNames[pedal]);
                return false;
            }

            object payload = GetMember(config, "payloadPedalConfig_");
            if (payload == null)
            {
                _lastError = "payloadPedalConfig_ unavailable";
                return false;
            }

            FieldInfo field = payload.GetType().GetField(fieldName, AnyInstance);
            if (field == null)
            {
                _lastError = string.Format("{0} unavailable", fieldName);
                return false;
            }

            double current = ToDouble(field.GetValue(payload));
            if (double.IsNaN(current))
            {
                _lastError = string.Format("{0} value unreadable", fieldName);
                return false;
            }

            double next = ClampConfigValue(pedal, fieldName, current + delta, payload);
            field.SetValue(payload, ConvertForField(field.FieldType, next));
            SetMember(config, "payloadPedalConfig_", payload);
            configArray.SetValue(config, pedal);
            MirrorConfigToKnownBuffers(pedal, config);
            QueueAndSendConfig(pedal, config);
            _lastError = string.Empty;
            return true;
        }

        private double ClampConfigValue(int pedal, string fieldName, double value, object payload)
        {
            double travelMin = ToDouble(GetMember(payload, "pedalStartPosition"));
            double travelMax = ToDouble(GetMember(payload, "pedalEndPosition"));
            double preload = ToDouble(GetMember(payload, "preloadForce"));
            double maxForce = ToDouble(GetMember(payload, "maxForce"));

            switch (fieldName)
            {
                case "pedalStartPosition":
                    if (double.IsNaN(travelMax)) travelMax = 95;
                    return Math.Max(5, Math.Min(value, Math.Min(94, travelMax - 1)));
                case "pedalEndPosition":
                    if (double.IsNaN(travelMin)) travelMin = 5;
                    return Math.Min(95, Math.Max(value, Math.Max(6, travelMin + 1)));
                case "preloadForce":
                    if (double.IsNaN(maxForce) || maxForce <= 0) maxForce = 200;
                    return Math.Max(0, Math.Min(value, maxForce - 1));
                case "maxForce":
                    if (double.IsNaN(preload)) preload = 0;
                    return Math.Max(preload + 1, Math.Min(value, 200));
                default:
                    return value;
            }
        }

        private void QueueAndSendConfig(int pedal, object config)
        {
            QueueAndSendConfig(pedal, config, true, false);
        }

        private void QueueAndSendConfig(int pedal, object config, bool markModified, bool applyingConfig)
        {
            object plugin = FindPedalPlugin();
            if (plugin == null)
            {
                return;
            }

            try
            {
                SetArrayMember(plugin, "BufferConfig_st", pedal, config);
                SetArrayMember(plugin, "IsGetConfigSendRequest", pedal, true);
                SetArrayMember(plugin, "ConfigBufferGet_lastTime", pedal, DateTime.Now);

                object calculations = GetMember(plugin, "_calculations");
                SetArrayMember(calculations, "IsModifiedConfigNotSave", pedal, markModified);
                SetMember(calculations, "IsApplyingConfig", applyingConfig);
                if (applyingConfig)
                {
                    SetMember(calculations, "configApplyLockLast", DateTime.Now);
                }

                object configService = GetMember(plugin, "ConfigService");
                Invoke(configService, "UpdateConfigLabelDefaultAndEditing");

                MethodInfo send = plugin.GetType().GetMethod("SendConfigWithoutSaveToEEPROM", AnyInstance);
                if (send != null)
                {
                    send.Invoke(plugin, new[] { config, (object)(byte)pedal });
                }
            }
            catch (Exception ex)
            {
                _lastError = ex.InnerException != null ? ex.InnerException.Message : ex.Message;
            }
        }

        private string ReadConfigListName(int index)
        {
            object item = GetConfigListItem(index);
            string text = Convert.ToString(GetMember(item, "ListNameOrig"), CultureInfo.InvariantCulture);
            if (string.IsNullOrWhiteSpace(text))
            {
                text = Path.GetFileNameWithoutExtension(GetConfigFileName(index));
            }

            return string.IsNullOrWhiteSpace(text) ? "--" : text;
        }

        private string ReadConfigStatusText(int pedal, int index)
        {
            bool active = IsConfigActive(pedal, index);
            bool startup = IsConfigStartup(pedal, index);
            if (active && startup)
            {
                return "ACTIVE  STARTUP";
            }

            if (active)
            {
                return "ACTIVE";
            }

            return startup ? "STARTUP" : string.Empty;
        }

        private bool IsConfigActive(int pedal, int index)
        {
            string fileName = GetConfigFileName(index);
            if (string.IsNullOrEmpty(fileName))
            {
                return false;
            }

            object calculations = GetMember(FindPedalPlugin(), "_calculations");
            string active = Convert.ToString(GetArrayMember(calculations, "ConfigEditing", pedal), CultureInfo.InvariantCulture);
            return string.Equals(fileName, active, StringComparison.OrdinalIgnoreCase);
        }

        private bool IsConfigStartup(int pedal, int index)
        {
            string fileName = GetConfigFileName(index);
            if (string.IsNullOrEmpty(fileName))
            {
                return false;
            }

            object settings = GetMember(FindPedalPlugin(), "Settings");
            string startup = Convert.ToString(GetArrayMember(settings, "DefaultConfig", pedal), CultureInfo.InvariantCulture);
            return string.Equals(fileName, startup, StringComparison.OrdinalIgnoreCase);
        }

        private string GetConfigFileName(int index)
        {
            object item = GetConfigListItem(index);
            return Convert.ToString(GetMember(item, "FileName"), CultureInfo.InvariantCulture);
        }

        private object GetConfigListItem(int index)
        {
            object list = GetConfigList();
            if (list == null || index < 0)
            {
                return null;
            }

            IList indexed = list as IList;
            if (indexed != null)
            {
                return index < indexed.Count ? indexed[index] : null;
            }

            IEnumerable enumerable = list as IEnumerable;
            if (enumerable == null)
            {
                return null;
            }

            int current = 0;
            foreach (object item in enumerable)
            {
                if (current == index)
                {
                    return item;
                }

                current++;
            }

            return null;
        }

        private object GetConfigList()
        {
            object plugin = FindPedalPlugin();
            object configService = GetMember(plugin, "ConfigService");
            if (configService == null)
            {
                return null;
            }

            object list = GetMember(configService, "ConfigList");
            if (list == null || (DateTime.Now - _lastConfigListRefresh).TotalSeconds > 2)
            {
                Invoke(configService, "RefreshConfigList");
                _lastConfigListRefresh = DateTime.Now;
                list = GetMember(configService, "ConfigList");
            }

            return list;
        }

        private void ApplyConfigToPedal(int pedal, int index)
        {
            object plugin = FindPedalPlugin();
            object configService = GetMember(plugin, "ConfigService");
            object settings = GetMember(plugin, "Settings");
            if (plugin == null || configService == null || settings == null)
            {
                _lastError = "Config service unavailable";
                return;
            }

            object originalSelected = GetMember(settings, "table_selected");
            try
            {
                SetMemberCoerced(settings, "table_selected", pedal);
                object item = GetConfigListItem(index);
                if (item == null)
                {
                    _lastError = string.Format("Config slot {0} unavailable", index + 1);
                    return;
                }

                string fileName = Convert.ToString(GetMember(item, "FileName"), CultureInfo.InvariantCulture);
                string fullPath = Convert.ToString(GetMember(item, "FullPath"), CultureInfo.InvariantCulture);
                if (string.IsNullOrWhiteSpace(fileName) || string.IsNullOrWhiteSpace(fullPath))
                {
                    _lastError = "Config item incomplete";
                    return;
                }

                object config = Invoke(configService, "ReadConfig", new object[] { fullPath });
                if (config == null)
                {
                    _lastError = string.Format("ReadConfig failed for {0}", fileName);
                    return;
                }

                object hashMap = GetMember(configService, "ConfigHashMap");
                object hash = Invoke(hashMap, "Fnv1aHash", new object[] { fileName });
                object header = GetMember(config, "payloadHeader_");
                object payload = GetMember(config, "payloadPedalConfig_");

                SetMemberCoerced(header, "PedalTag", pedal);
                SetMemberCoerced(header, "storeToEeprom", 0);
                SetMemberCoerced(payload, "pedal_type", pedal);
                if (hash != null)
                {
                    SetMemberCoerced(payload, "configHash_u32", hash);
                }

                SetMember(config, "payloadHeader_", header);
                SetMember(config, "payloadPedalConfig_", payload);
                object calculations = GetMember(plugin, "_calculations");
                SetArrayMember(calculations, "ConfigEditing", pedal, fileName);
                SetArrayMember(calculations, "IsModifiedConfigNotSave", pedal, false);

                MirrorConfigToKnownBuffers(pedal, config);
                QueueAndSendConfig(pedal, config, false, true);
                _lastError = string.Empty;
            }
            catch (Exception ex)
            {
                _lastError = ex.InnerException != null ? ex.InnerException.Message : ex.Message;
            }
            finally
            {
                SetMemberCoerced(settings, "table_selected", originalSelected);
                Invoke(configService, "UpdateConfigLabelDefaultAndEditing");
            }
        }

        private bool ReadEffectEnabled(int pedal, string effectKey)
        {
            object settings = GetMember(FindPedalPlugin(), "Settings");
            string memberName = EffectMemberName(effectKey);
            object value = GetArrayMember(settings, memberName, pedal);
            if (value is bool)
            {
                return (bool)value;
            }

            return ToDouble(value) > 0;
        }

        private void ToggleEffect(int pedal, string effectKey)
        {
            SetEffect(pedal, effectKey, !ReadEffectEnabled(pedal, effectKey));
        }

        private void SetEffect(int pedal, string effectKey, bool enabled)
        {
            object plugin = FindPedalPlugin();
            object settings = GetMember(plugin, "Settings");
            string memberName = EffectMemberName(effectKey);
            object array = GetMember(settings, memberName);
            Array values = array as Array;
            if (values != null && pedal >= 0 && pedal < values.Length)
            {
                Type elementType = values.GetType().GetElementType();
                object next = elementType == typeof(bool) ? (object)enabled : (enabled ? 1 : 0);
                values.SetValue(next, pedal);
                SetMember(plugin, "Page_update_flag", true);
                _lastError = string.Empty;
                return;
            }

            _lastError = string.Format("{0} unavailable", memberName);
        }

        private string EffectMemberName(string effectKey)
        {
            switch (effectKey)
            {
                case "ABS": return "ABS_enable_flag";
                case "RPM": return "RPM_enable_flag";
                case "Gforce": return "G_force_enable_flag";
                case "WheelSlip": return "WS_enable_flag";
                case "RoadImpact": return "Road_impact_enable_flag";
                default: return string.Empty;
            }
        }

        private bool TryGetConfig(int pedal, out object config, out Array configArray, out string source)
        {
            config = null;
            configArray = null;
            source = string.Empty;

            object plugin = FindPedalPlugin();
            if (plugin == null)
            {
                return false;
            }

            object wpf = GetMember(plugin, "wpfHandle");
            if (TryUseConfigArray(GetMember(wpf, "dap_config_st"), pedal, out config, out configArray))
            {
                source = "wpfHandle.dap_config_st";
                return true;
            }

            object profileService = GetMember(plugin, "ProfileServicePlugin");
            if (TryUseConfigArray(GetMember(profileService, "ConfigBuffer"), pedal, out config, out configArray))
            {
                source = "ProfileServicePlugin.ConfigBuffer";
                return true;
            }

            if (TryUseConfigArray(GetMember(plugin, "BufferConfig_st"), pedal, out config, out configArray))
            {
                source = "BufferConfig_st";
                return true;
            }

            return false;
        }

        private bool TryUseConfigArray(object value, int pedal, out object config, out Array configArray)
        {
            config = null;
            configArray = value as Array;
            if (configArray == null || pedal < 0 || pedal >= configArray.Length)
            {
                return false;
            }

            object candidate = configArray.GetValue(pedal);
            if (!IsUsableConfig(candidate))
            {
                return false;
            }

            config = candidate;
            return true;
        }

        private bool IsUsableConfig(object config)
        {
            if (config == null)
            {
                return false;
            }

            object payload = GetMember(config, "payloadPedalConfig_");
            double maxForce = ToDouble(GetMember(payload, "maxForce"));
            double endTravel = ToDouble(GetMember(payload, "pedalEndPosition"));
            return !double.IsNaN(maxForce) && !double.IsNaN(endTravel) && (maxForce > 0 || endTravel > 0);
        }

        private void MirrorConfigToKnownBuffers(int pedal, object config)
        {
            object plugin = FindPedalPlugin();
            if (plugin == null)
            {
                return;
            }

            object wpf = GetMember(plugin, "wpfHandle");
            SetArrayMember(wpf, "dap_config_st", pedal, config);
            SetArrayMember(plugin, "BufferConfig_st", pedal, config);
            object profileService = GetMember(plugin, "ProfileServicePlugin");
            SetArrayMember(profileService, "ConfigBuffer", pedal, config);
        }

        private string ReadConnectionStatus(int pedal)
        {
            object plugin = FindPedalPlugin();
            object calculations = GetMember(plugin, "_calculations");

            string wireless = Convert.ToString(GetArrayMember(calculations, "pedalWirelessStatus", pedal), CultureInfo.InvariantCulture);
            string serial = Convert.ToString(GetArrayMember(calculations, "pedalSerialStatus", pedal), CultureInfo.InvariantCulture);

            if (string.Equals(wireless, "PEDAL_WIRELESS_IS_READY", StringComparison.OrdinalIgnoreCase))
            {
                return "WIRELESS";
            }

            if (string.Equals(serial, "PEDAL_IS_READY", StringComparison.OrdinalIgnoreCase))
            {
                return "USB";
            }

            if (wireless != null && wireless.IndexOf("GET_BASIC", StringComparison.OrdinalIgnoreCase) >= 0 ||
                serial != null && serial.IndexOf("GET_BASIC", StringComparison.OrdinalIgnoreCase) >= 0 ||
                wireless != null && wireless.IndexOf("ENTRY", StringComparison.OrdinalIgnoreCase) >= 0 ||
                serial != null && serial.IndexOf("ENTRY", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return "CONNECTING";
            }

            object status = GetArrayMember(GetMember(plugin, "PedalStatusInstance"), "PedalConnectionStatus", pedal);
            string text = Convert.ToString(status, CultureInfo.InvariantCulture);
            return string.IsNullOrWhiteSpace(text) ? "OFFLINE" : text.ToUpperInvariant();
        }

        private bool IsPedalReady(int pedal)
        {
            string status = ReadConnectionStatus(pedal);
            return status == "USB" || status == "WIRELESS" || status == "CONNECTED";
        }

        private double ReadInputPercent(int pedal)
        {
            object plugin = FindPedalPlugin();
            if (plugin == null)
            {
                return double.NaN;
            }

            object wpf = GetMember(plugin, "wpfHandle");
            double raw = ToDouble(GetArrayMember(wpf, "Pedal_position_reading", pedal));
            if (!double.IsNaN(raw))
            {
                return NormalizeInputPercent(raw);
            }

            int selected = GetSelectedPedalIndex();
            if (selected == pedal)
            {
                raw = ToDouble(GetMember(plugin, "pedal_state_in_ratio"));
                if (!double.IsNaN(raw))
                {
                    return NormalizeInputPercent(raw);
                }
            }

            return double.NaN;
        }

        private double NormalizeInputPercent(double value)
        {
            if (double.IsNaN(value))
            {
                return double.NaN;
            }

            if (value > 100.0)
            {
                value = value / 65535.0 * 100.0;
            }

            return Math.Max(0.0, Math.Min(100.0, value));
        }

        private string GetSelectedPedalName()
        {
            int selected = GetSelectedPedalIndex();
            if (selected < 0 || selected >= PedalNames.Length)
            {
                return "--";
            }

            return PedalNames[selected];
        }

        private int GetSelectedPedalIndex()
        {
            object settings = GetMember(FindPedalPlugin(), "Settings");
            int selected = (int)ToDouble(GetMember(settings, "table_selected"));
            if (selected < 0 || selected >= PedalNames.Length)
            {
                return -1;
            }

            return selected;
        }

        private string GetStringFromMemberPath(string memberPath, string fallback, bool allowEmpty)
        {
            object value = FindPedalPlugin();
            foreach (string segment in memberPath.Split('.'))
            {
                value = GetMember(value, segment);
                if (value == null)
                {
                    return fallback;
                }
            }

            string text = Convert.ToString(value, CultureInfo.InvariantCulture);
            if (!allowEmpty && string.IsNullOrEmpty(text))
            {
                return fallback;
            }

            return string.IsNullOrEmpty(text) ? fallback : text;
        }

        private string FormatValue(double value, string format, string unit)
        {
            if (double.IsNaN(value))
            {
                return "--";
            }

            return value.ToString(format, CultureInfo.InvariantCulture) + unit;
        }

        private object GetArrayMember(object owner, string memberName, int index)
        {
            object array = GetMember(owner, memberName);
            Array values = array as Array;
            if (values != null && index >= 0 && index < values.Length)
            {
                return values.GetValue(index);
            }

            return null;
        }

        private bool SetArrayMember(object owner, string memberName, int index, object value)
        {
            object array = GetMember(owner, memberName);
            Array values = array as Array;
            if (values != null && index >= 0 && index < values.Length)
            {
                values.SetValue(value, index);
                return true;
            }

            return false;
        }

        private object GetMember(object owner, string name)
        {
            if (owner == null || string.IsNullOrEmpty(name))
            {
                return null;
            }

            Type type = owner.GetType();
            PropertyInfo property = type.GetProperty(name, AnyInstance);
            if (property != null)
            {
                return property.GetValue(owner, null);
            }

            FieldInfo field = type.GetField(name, AnyInstance);
            if (field != null)
            {
                return field.GetValue(owner);
            }

            return null;
        }

        private bool SetMember(object owner, string name, object value)
        {
            if (owner == null || string.IsNullOrEmpty(name))
            {
                return false;
            }

            Type type = owner.GetType();
            PropertyInfo property = type.GetProperty(name, AnyInstance);
            if (property != null && property.CanWrite)
            {
                property.SetValue(owner, value, null);
                return true;
            }

            FieldInfo field = type.GetField(name, AnyInstance);
            if (field != null)
            {
                field.SetValue(owner, value);
                return true;
            }

            return false;
        }

        private bool SetMemberCoerced(object owner, string name, object value)
        {
            if (owner == null || string.IsNullOrEmpty(name))
            {
                return false;
            }

            Type type = owner.GetType();
            PropertyInfo property = type.GetProperty(name, AnyInstance);
            if (property != null && property.CanWrite)
            {
                property.SetValue(owner, CoerceValue(value, property.PropertyType), null);
                return true;
            }

            FieldInfo field = type.GetField(name, AnyInstance);
            if (field != null)
            {
                field.SetValue(owner, CoerceValue(value, field.FieldType));
                return true;
            }

            return false;
        }

        private object Invoke(object owner, string name)
        {
            if (owner == null)
            {
                return null;
            }

            MethodInfo method = owner.GetType().GetMethod(name, AnyInstance, null, Type.EmptyTypes, null);
            return method == null ? null : method.Invoke(owner, null);
        }

        private object Invoke(object owner, string name, object[] args)
        {
            if (owner == null)
            {
                return null;
            }

            MethodInfo[] methods = owner.GetType().GetMethods(AnyInstance);
            foreach (MethodInfo method in methods)
            {
                if (!string.Equals(method.Name, name, StringComparison.Ordinal) || method.GetParameters().Length != args.Length)
                {
                    continue;
                }

                return method.Invoke(owner, args);
            }

            return null;
        }

        private double ToDouble(object value)
        {
            if (value == null)
            {
                return double.NaN;
            }

            try
            {
                return Convert.ToDouble(value, CultureInfo.InvariantCulture);
            }
            catch
            {
                return double.NaN;
            }
        }

        private object ConvertForField(Type fieldType, double value)
        {
            if (fieldType == typeof(byte))
            {
                return (byte)Math.Round(Math.Max(byte.MinValue, Math.Min(byte.MaxValue, value)));
            }

            if (fieldType == typeof(float))
            {
                return (float)value;
            }

            if (fieldType == typeof(double))
            {
                return value;
            }

            if (fieldType == typeof(int))
            {
                return (int)Math.Round(value);
            }

            if (fieldType == typeof(uint))
            {
                return (uint)Math.Round(Math.Max(0, value));
            }

            return Convert.ChangeType(value, fieldType, CultureInfo.InvariantCulture);
        }

        private object CoerceValue(object value, Type targetType)
        {
            if (value == null)
            {
                return null;
            }

            Type nullable = Nullable.GetUnderlyingType(targetType);
            if (nullable != null)
            {
                targetType = nullable;
            }

            if (targetType.IsInstanceOfType(value))
            {
                return value;
            }

            if (targetType.IsEnum)
            {
                if (value is string)
                {
                    return Enum.Parse(targetType, (string)value, true);
                }

                return Enum.ToObject(targetType, value);
            }

            return Convert.ChangeType(value, targetType, CultureInfo.InvariantCulture);
        }
    }
}
